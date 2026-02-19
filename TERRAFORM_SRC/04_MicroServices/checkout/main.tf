# ------------------------------------------------------------------------------
# 1. SECURITY GROUP (FIREWALL)
# ------------------------------------------------------------------------------
resource "aws_security_group" "redis_security_group" {
  name        = "${local.name_prefix}-redis-sg"
  description = "Allows Redis traffic from EKS cluster"
  vpc_id      = local.vpc_id

  tags = {
    Name = "${local.name_prefix}-redis-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "redis_ingress_from_eks" {
  security_group_id            = aws_security_group.redis_security_group.id
  referenced_security_group_id = local.cluster_security_group_id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all_egress_ipv4" {
  security_group_id = aws_security_group.redis_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ------------------------------------------------------------------------------
# 2. REDIS ELASTICACHE CLUSTER
# ------------------------------------------------------------------------------
resource "aws_elasticache_replication_group" "redis_cluster" {
  replication_group_id = "${local.name_prefix}-redis"
  description          = "Redis cluster for checkout service"

  engine         = "redis"
  engine_version = "7.1"
  node_type      = "cache.t4g.micro"
  port           = 6379

  subnet_group_name  = local.db_subnet_group_id
  security_group_ids = [aws_security_group.redis_security_group.id]

  at_rest_encryption_enabled = false
  transit_encryption_enabled = false

  num_cache_clusters = 1
  apply_immediately  = true

  tags = {
    Name = "${local.name_prefix}-redis"
  }
}

# ------------------------------------------------------------------------------
# 3. SSM PARAMETER STORE
# ------------------------------------------------------------------------------
resource "aws_ssm_parameter" "redis_host" {
  name  = "${local.path_prefix}/redis_host"
  type  = "String"
  value = aws_elasticache_replication_group.redis_cluster.primary_endpoint_address

  tags = {
    Name = "${local.name_prefix}-redis-host"
  }
}

resource "aws_ssm_parameter" "redis_port" {
  name  = "${local.path_prefix}/redis_port"
  type  = "String"
  value = tostring(aws_elasticache_replication_group.redis_cluster.port)

  tags = {
    Name = "${local.name_prefix}-redis-port"
  }
}

# ------------------------------------------------------------------------------
# 4. IAM ROLE AND PERMISSIONS (EKS POD IDENTITY)
# ------------------------------------------------------------------------------
resource "aws_iam_policy" "ssm_policy" {
  name        = "${local.name_prefix}-ssm-policy"
  description = "IAM policy for checkout service to access Redis SSM parameters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Effect = "Allow"
        Resource = [
          aws_ssm_parameter.redis_host.arn,
          aws_ssm_parameter.redis_port.arn
        ]
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-ssm-policy"
  }
}

resource "aws_iam_role" "service_role" {
  name = "${local.name_prefix}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["sts:AssumeRole", "sts:TagSession"]
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  policy_arn = aws_iam_policy.ssm_policy.arn
  role       = aws_iam_role.service_role.name
}

# ------------------------------------------------------------------------------
# 5. EKS POD IDENTITY ASSOCIATION
# ------------------------------------------------------------------------------
resource "aws_eks_pod_identity_association" "service_pod_identity" {
  cluster_name    = data.terraform_remote_state.eks.outputs.eks_cluster_name
  namespace       = "default"
  service_account = "checkout"
  role_arn        = aws_iam_role.service_role.arn

  tags = {
    Name = "${local.name_prefix}-pod-identity-association"
  }
}
