# main.tf

# --- 1. Security Group for RDS ---
resource "aws_security_group" "catalog_db_sg" {
  name        = "catalog_db_sg"
  description = "Security group for catalog database"
  vpc_id      = local.vpc_id
  tags = merge(var.tags, {
    Name = "${local.name}-catalog-db-sg"
  })

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


### DB Instance
module "rds_catalog" {
  source                      = "terraform-aws-modules/rds/aws"
  version                     = "7.1.0"
  identifier                  = "${local.name}-catalog-db"
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
  password_wo         = var.db_password
  password_wo_version = "1"
  port                = 3306

  multi_az               = false
  db_subnet_group_name   = local.db_subnet_group_id
  vpc_security_group_ids = [aws_security_group.catalog_db_sg.id]

  backup_retention_period = 0
  backup_window           = "07:00-09:00"


  skip_final_snapshot = true
  deletion_protection = false

  tags = merge(var.tags, {
    Name = "${local.name}-catalog-db"
  })



}

### IAM Policy for Service Account
resource "aws_iam_policy" "catalog_policy" {
  name        = "catalog_policy"
  description = "IAM policy for catalog service account"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# ---- IAM Role
resource "aws_iam_role" "catalog_role" {
  name = "catalog_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "catalog_policy_attachment" {
  policy_arn = aws_iam_policy.catalog_policy.arn
  role       = aws_iam_role.catalog_role.name
}


# --- The assocaition(Binding identity to K8s)
resource "aws_eks_pod_identity_association" "catalog" {
  cluster_name    = data.terraform_remote_state.eks.outputs.cluster_name
  namespace       = "default"
  service_account = "catalog-mysql-sa"
  role_arn        = aws_iam_role.catalog_secrets_role.arn
}
