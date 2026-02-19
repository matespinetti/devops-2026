# ------------------------------------------------------------------------------
# 1. SECURITY GROUP (POSTGRESQL)
# ------------------------------------------------------------------------------
resource "aws_security_group" "database_security_group" {
  name        = "${local.name_prefix}-db-sg"
  description = "Security group for orders service database"
  vpc_id      = local.vpc_id

  tags = {
    Name = "${local.name_prefix}-db-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "postgres_ingress_from_eks" {
  security_group_id            = aws_security_group.database_security_group.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = local.cluster_security_group_id
}

resource "aws_vpc_security_group_egress_rule" "all_egress_ipv4" {
  security_group_id = aws_security_group.database_security_group.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ------------------------------------------------------------------------------
# 2. SQS QUEUE (MESSAGING)
# ------------------------------------------------------------------------------
resource "aws_sqs_queue" "queue" {
  name                      = "${local.name_prefix}-queue"
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10

  tags = {
    Name = "${local.name_prefix}-queue"
  }
}

# ------------------------------------------------------------------------------
# 3. DATABASE (POSTGRESQL)
# ------------------------------------------------------------------------------
resource "random_password" "db_password" {
  length  = 16
  special = false
}

module "orders_db" {
  source = "terraform-aws-modules/rds/aws"

  identifier           = "${local.name_prefix}-db"
  engine               = "postgres"
  engine_version       = "17.6"
  major_engine_version = "17"
  instance_class       = "db.t4g.micro"
  allocated_storage    = 20
  storage_type         = "gp3"

  create_db_option_group    = false
  create_db_parameter_group = false

  username                    = var.db_user
  manage_master_user_password = false
  password_wo                 = random_password.db_password.result
  password_wo_version         = "1"
  db_name                     = var.db_name

  db_subnet_group_name   = local.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.database_security_group.id]

  multi_az                     = false
  backup_retention_period      = 1
  skip_final_snapshot          = true
  performance_insights_enabled = false
  storage_encrypted            = true
  deletion_protection          = false

  tags = {
    Name = "${local.name_prefix}-db"
  }
}

# ------------------------------------------------------------------------------
# 4. SECRETS & CONFIG
# ------------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "orders_secrets" {
  name                    = "${local.path_prefix}/secrets"
  recovery_window_in_days = 0

  tags = {
    Name = "${local.path_prefix}/secrets"
  }
}

resource "aws_secretsmanager_secret_version" "orders_secrets_version" {
  secret_id = aws_secretsmanager_secret.orders_secrets.id

  secret_string = jsonencode({
    DB_USER = var.db_user
    DB_PASS = random_password.db_password.result
    DB_HOST = module.orders_db.db_instance_address
    DB_PORT = module.orders_db.db_instance_port
    DB_NAME = var.db_name

    SQS_QUEUE_URL = aws_sqs_queue.queue.url
  })
}

# ------------------------------------------------------------------------------
# 5. IAM ROLE AND PERMISSIONS (EKS POD IDENTITY)
# ------------------------------------------------------------------------------
resource "aws_iam_policy" "secrets_policy" {
  name        = "${local.name_prefix}-secrets-policy"
  description = "IAM policy for orders service to access its secret"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Effect   = "Allow"
        Resource = aws_secretsmanager_secret.orders_secrets.arn
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-secrets-policy"
  }
}

resource "aws_iam_policy" "sqs_policy" {
  name        = "${local.name_prefix}-sqs-policy"
  description = "IAM policy for orders service to access its SQS queue"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Effect   = "Allow"
        Resource = aws_sqs_queue.queue.arn
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-sqs-policy"
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

resource "aws_iam_role_policy_attachment" "sqs_policy_attachment" {
  policy_arn = aws_iam_policy.sqs_policy.arn
  role       = aws_iam_role.service_role.name
}

# ------------------------------------------------------------------------------
# 6. EKS POD IDENTITY ASSOCIATION
# ------------------------------------------------------------------------------
resource "aws_eks_pod_identity_association" "service_pod_identity" {
  cluster_name    = data.terraform_remote_state.eks.outputs.eks_cluster_name
  namespace       = "default"
  service_account = "orders"
  role_arn        = aws_iam_role.service_role.arn

  tags = {
    Name = "${local.name_prefix}-pod-identity-association"
  }
}
