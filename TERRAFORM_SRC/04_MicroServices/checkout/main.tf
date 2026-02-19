# ------------------------------------------------------------------------------
# 1. SECURITY GROUP (Firewall)
# ------------------------------------------------------------------------------

resource "aws_security_group" "checkout_redis_sg" {
  name        = "${local.name}-redis-sg"
  description = "Allows Redis traffic from EKS cluster"

  vpc_id = local.vpc_id
  tags = {
    Name = "${local.name}-redis-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_redis_from_eks" {
  security_group_id            = aws_security_group.checkout_redis_sg.id
  referenced_security_group_id = local.cluster_security_group_id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"

}


resource "aws_vpc_security_group_egress_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.checkout_redis_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


# ------------------------------------------------------------------------------
# 2. REDIS ELASTICACHE CLUSTER
# ------------------------------------------------------------------------------

resource "aws_elasticache_replication_group" "checkout_redis" {
  replication_group_id = "${local.name}-redis"
  description          = "Redis cluster for checkout service"

  engine         = "redis"
  engine_version = "7.1"
  node_type      = "cache.t4g.micro"
  port           = 6379


  #Networking
  subnet_group_name    = local.db_subnet_group_id
  security_group_names = [aws_security_group.checkout_redis_sg.name]

  at_rest_encryption_enabled = false
  transit_encryption_enabled = false

  num_cache_clusters = 1
  apply_immediately  = true
  tags = {
    Name = "${local.name}-redis"
  }
}

# ------------------------------------------------------------------------------
# 3. CONFIGURATION (SSM Parameter Store)
# ------------------------------------------------------------------------------
# Ya no necesitamos Secrets Manager porque NO HAY password.
# Solo guardamos el Host y el Port en SSM para que Kubernetes los lea.


resource "aws_ssm_parameter" "redis_host" {
  name  = "/${var.business_division}/${var.environment_name}/checkout/redis_host"
  type  = "String"
  value = aws_elasticache_replication_group.checkout_redis.primary_endpoint_address
}

resource "aws_ssm_parameter" "redis_port" {
  name  = "/${var.business_division}/${var.environment_name}/checkout/redis_port"
  type  = "String"
  value = aws_elasticache_replication_group.checkout_redis.port
}


# ------------------------------------------------------------------------------
# 4. IAM ROLE AND PERMISSIONS(EKS Pod Identity )
# ------------------------------------------------------------------------------
resource "aws_iam_policy" "checkout_ssm_policy" {
  name        = "${local.name}-ssm-policy"
  description = "IAM policy for checkout service to access its SSM Parameter Store"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Effect   = "Allow"
        Resource = aws_ssm_parameter.redis_host.arn
      }
    ]
  })
}

resource "aws_iam_role" "checkout_role" {
  name = "checkout_role"
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
    Name = "${local.name}-role"
  }
}

resource "aws_iam_role_policy_attachment" "checkout_ssm_policy_attachment" {
  policy_arn = aws_iam_policy.checkout_ssm_policy.arn
  role       = aws_iam_role.checkout_role.name
}


# ------------------------------------------------------------------------------
# 5. EKS POD IDENTITY ASSOCIATION
# ------------------------------------------------------------------------------
resource "aws_eks_pod_identity_association" "checkout" {
  cluster_name    = data.terraform_remote_state.eks.outputs.cluster_name
  namespace       = "default"
  service_account = "checkout"
  role_arn        = aws_iam_role.checkout_role.arn
  tags = {
    Name = "${local.name}-pod-identity-association"
  }
}
