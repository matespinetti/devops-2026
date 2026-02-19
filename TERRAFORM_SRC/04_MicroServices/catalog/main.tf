# main.tf

# ------------------------------------------------------------------------------
# 1. Security Group for RDS 
# ------------------------------------------------------------------------------
resource "aws_security_group" "rds_sg" {
  name        = "catalog_db_sg"
  description = "Security group for RDS"
  vpc_id      = local.vpc_id
  tags = {
    Name = "${local.name}-rds-sg"
  }

}

# ------------------------------------------------------------------------------
# 2. Security Group for Catalog DB 
# ------------------------------------------------------------------------------
resource "aws_security_group" "catalog_db_sg" {
  name        = "catalog_db_sg"
  description = "Security group for catalog database"
  vpc_id      = local.vpc_id
  tags = {
    Name = "${local.name}-db-sg"
  }
}



resource "aws_vpc_security_group_ingress_rule" "allow_mysql_ipv4" {
  security_group_id            = aws_security_group.catalog_db_sg.id
  referenced_security_group_id = local.cluster_security_group_id
  from_port                    = 3306
  ip_protocol                  = "tcp"
  to_port                      = 3306
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.catalog_db_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


# ------------------------------------------------------------------------------
# 3. SECRET GENERATION 
# ------------------------------------------------------------------------------

resource "random_password" "catalog_db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}




# ------------------------------------------------------------------------------
# 4. RDS Instance 
# ------------------------------------------------------------------------------
module "rds" {
  source                      = "terraform-aws-modules/rds/aws"
  version                     = "7.1.0"
  identifier                  = "${local.name}-db"
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
  password_wo_version = "1"
  port                = 3306

  multi_az               = false
  db_subnet_group_name   = local.db_subnet_group_id
  vpc_security_group_ids = [aws_security_group.catalog_db_sg.id]

  backup_retention_period = 0
  backup_window           = "07:00-09:00"


  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "${local.name}-db"
  }



}


# ------------------------------------------------------------------------------
# 5. SECRET 
# ------------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "catalog_config" {
  name                    = "${var.business_division}/${var.environment_name}/catalog/secrets"
  description             = "Password for catalog database"
  recovery_window_in_days = 0
  tags = {
    Name = "${var.business_division}/${var.environment_name}/catalog/secrets"
  }
}

resource "aws_secretsmanager_secret_version" "catalog_config_val" {
  secret_id = aws_secretsmanager_secret.catalog_config.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.catalog_db_password.result
    host     = module.rds.db_instance_address
    port     = module.rds.db_instance_port
    db_name  = module.rds.db_name
    engine   = "mysql"

  })
}


# ------------------------------------------------------------------------------
# 6. IAM ROLE
# ------------------------------------------------------------------------------

resource "aws_iam_policy" "catalog_secret_policy" {
  name        = "${local.name}-secret-policy"
  description = "IAM policy for catalog service to access its secrets manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Effect   = "Allow"
        Resource = aws_secretsmanager_secret.catalog_config.arn
      }
    ]
  })
}
resource "aws_iam_role" "catalog_role" {
  name = "catalog_role"
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

resource "aws_iam_role_policy_attachment" "catalog_secret_policy_attachment" {
  policy_arn = aws_iam_policy.catalog_secret_policy.arn
  role       = aws_iam_role.catalog_role.name
}


# ------------------------------------------------------------------------------
# 7. EKS POD IDENTITY ASSOCIATION
# ------------------------------------------------------------------------------
resource "aws_eks_pod_identity_association" "catalog" {
  cluster_name    = data.terraform_remote_state.eks.outputs.cluster_name
  namespace       = "default"
  service_account = "catalog"
  role_arn        = aws_iam_role.catalog_role.arn
  tags = {
    Name = "${local.name}-pod-identity-association"
  }
}
