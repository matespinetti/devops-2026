# ------------------------------------------------------------------------------
# 1. SECURITY GROUP (PostgreSQL)
# ------------------------------------------------------------------------------

resource "aws_security_group" "orders_db_sg" {
  name        = "${local.name}-sg"
  description = "Security group for orders service database"
  vpc_id      = local.vpc_id
  tags = {
    Name = "${local.name}-db-sg"
  }

}
resource "aws_vpc_security_group_ingress_rule" "allow_pgsql_from_eks" {
  security_group_id            = aws_security_group.orders_db_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = local.cluster_security_group_id

}

resource "aws_vpc_security_group_egress_rule" "allow_all_egress" {
  security_group_id = aws_security_group.orders_db_sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = ["0.0.0.0/0"]
}


# ------------------------------------------------------------------------------
# 2. SQS Queue(Messaging)
# ------------------------------------------------------------------------------
resource "aws_sqs_queue" "orders_queue" {
  name                      = "${local.name}-queue"
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  tags = {
    Name = "${local.name}-queue"
  }

}

# ------------------------------------------------------------------------------
# 3. DATABASE (PostgreSQL usando el Módulo RDS)
# ------------------------------------------------------------------------------
resource "random_password" "orders_db_password" {
  length           = 16
  special          = true
  override_special = "!@#$%^&*()_+"
}

module "orders_db" {
  source = "terraform-aws-modules/rds/aws"

  identifier           = "${local.name}-db"
  engine               = "postgres"
  engine_version       = "17.6"
  major_engine_version = "17"
  instance_class       = "db.t4g.micro"
  allocated_storage    = 20
  storage_type         = "gp3"

  username                    = var.db_user
  manage_master_user_password = false
  password_wo                 = random_password.orders_db_password.result
  password_wo_version         = "1"

  db_name = var.db_name

  subnet_ids             = local.private_subnet_ids
  vpc_security_group_ids = [aws_security_group.orders_db_sg.id]

  multi_az                     = false
  backup_retention_period      = 1
  skip_final_snapshot          = true
  performance_insights_enabled = false
  storage_encrypted            = true
  deletion_protection          = false


  tags = local.common_tags
}
# ------------------------------------------------------------------------------
# 4. SECRETS & CONFIG (The All-in-One Secret)
# ------------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "orders_secret" {
  name                    = "/${var.business_division}/${var.environment_name}/secrets"
  recovery_window_in_days = 0

}

resource "aws_secretsmanager_secret_version" "orders_secret_val" {
  secret_id = aws_secretsmanager_secret.orders_secret.id
  secret_string = jsonencode({
    DB_USER = var.db_user
    DB_PASS = random_password.orders_db_password.result
    DB_HOST = module.orders_db.db_instance_address
    DB_PORT = module.orders_db.db_instance_port
    DB_NAME = var.db_name

    #SQS
    SQS_QUEUE_URL = aws_sqs_queue.orders_queue.id

  })
}
# ------------------------------------------------------------------------------
# 5. IAM ROLE AND PERMISSIONS(EKS Pod Identity )
# ------------------------------------------------------------------------------

resource "aws_iam_policy" "orders_ssm_policy" {
  name        = "${local.name}-ssm-policy"
  description = "IAM policy for orders service to access its SSM Parameter Store"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Effect   = "Allow"
        Resource = aws_secretsmanager_secret.orders_secret.arn
      }
    ]
  })
}

resource "aws_iam_policy" "orders_sqs_policy" {
  name        = "${local.name}-sqs-policy"
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
        Resource = aws_sqs_queue.orders_queue.arn
      }
    ]
  })
}

resource "aws_iam_role" "orders_role" {
  name = "orders_role"
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

resource "aws_iam_role_policy_attachment" "orders_ssm_policy_attachment" {
  policy_arn = aws_iam_policy.orders_ssm_policy.arn
  role       = aws_iam_role.orders_role.name
}

resource "aws_iam_role_policy_attachment" "orders_sqs_policy_attachment" {
  policy_arn = aws_iam_policy.orders_sqs_policy.arn
  role       = aws_iam_role.orders_role.name
}

# ------------------------------------------------------------------------------
# 6. EKS POD IDENTITY ASSOCIATION
# ------------------------------------------------------------------------------
resource "aws_eks_pod_identity_association" "orders" {
  cluster_name    = data.terraform_remote_state.eks.outputs.cluster_name
  namespace       = "default"
  service_account = "orders"
  role_arn        = aws_iam_role.orders_role.arn
  tags = {
    Name = "${local.name}-pod-identity-association"
  }
}
