# ------------------------------------------------------------------------------
# 1. SECURITY GROUP FOR CATALOG DATABASE
# ------------------------------------------------------------------------------
resource "aws_security_group" "database_security_group" {
  name        = "${local.name_prefix}-db-sg"
  description = "Security group for catalog database"
  vpc_id      = local.vpc_id

  tags = {
    Name = "${local.name_prefix}-db-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "mysql_ingress_from_eks" {
  security_group_id            = aws_security_group.database_security_group.id
  referenced_security_group_id = local.cluster_security_group_id
  from_port                    = 3306
  ip_protocol                  = "tcp"
  to_port                      = 3306
}

resource "aws_vpc_security_group_egress_rule" "all_egress_ipv4" {
  security_group_id = aws_security_group.database_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ------------------------------------------------------------------------------
# 2. SECRET GENERATION
# ------------------------------------------------------------------------------
resource "random_password" "catalog_db_password" {
  length  = 16
  special = false
}

# ------------------------------------------------------------------------------
# 3. RDS INSTANCE
# ------------------------------------------------------------------------------
module "catalog_db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "7.1.0"

  identifier                  = "${local.name_prefix}-db"
  engine                      = "mysql"
  engine_version              = "8.4"
  family                      = "mysql8.4"
  major_engine_version        = "8.4"
  instance_class              = "db.t4g.micro"
  allocated_storage           = 20
  max_allocated_storage       = 100
  manage_master_user_password = false

  db_name             = var.db_name
  username            = var.db_username
  password_wo         = random_password.catalog_db_password.result
  password_wo_version = "2"
  port                = 3306

  multi_az               = false
  db_subnet_group_name   = local.db_subnet_group_id
  vpc_security_group_ids = [aws_security_group.database_security_group.id]

  backup_retention_period = 0
  backup_window           = "07:00-09:00"

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "${local.name_prefix}-db"
  }
}

# ------------------------------------------------------------------------------
# 4. SECRETS MANAGER
# ------------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "catalog_secrets" {
  name                    = "${local.path_prefix}/secrets"
  description             = "Connection config for catalog database"
  recovery_window_in_days = 0

  tags = {
    Name = "${local.path_prefix}/secrets"
  }
}

resource "aws_secretsmanager_secret_version" "catalog_secrets_version" {
  secret_id = aws_secretsmanager_secret.catalog_secrets.id

  secret_string = jsonencode({
    DB_USER = var.db_username
    DB_PASS = random_password.catalog_db_password.result
    DB_HOST = module.catalog_db.db_instance_address
    DB_PORT = module.catalog_db.db_instance_port
    DB_NAME = module.catalog_db.db_instance_name
    DB_TYPE = "mysql"
  })
}

# ------------------------------------------------------------------------------
# 5. IAM ROLE
# ------------------------------------------------------------------------------
resource "aws_iam_policy" "secrets_policy" {
  name        = "${local.name_prefix}-secrets-policy"
  description = "IAM policy for catalog service to access its secret"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Effect   = "Allow"
        Resource = aws_secretsmanager_secret.catalog_secrets.arn
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-secrets-policy"
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

resource "aws_iam_role_policy_attachment" "secrets_policy_attachment" {
  policy_arn = aws_iam_policy.secrets_policy.arn
  role       = aws_iam_role.service_role.name
}

# ------------------------------------------------------------------------------
# 6. EKS POD IDENTITY ASSOCIATION
# ------------------------------------------------------------------------------
resource "aws_eks_pod_identity_association" "service_pod_identity" {
  cluster_name    = data.terraform_remote_state.eks.outputs.eks_cluster_name
  namespace       = "default"
  service_account = "catalog"
  role_arn        = aws_iam_role.service_role.arn

  tags = {
    Name = "${local.name_prefix}-pod-identity-association"
  }
}
