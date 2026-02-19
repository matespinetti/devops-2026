

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "tfstate-dev-us-east-1-m75hlh"
    key    = "eks/dev/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "tfstate-dev-us-east-1-m75hlh"
    key    = "shared/dev/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  name                      = "${var.business_division}-${var.environment_name}-orders"
  vpc_id                    = data.terraform_remote_state.eks.outputs.vpc_id
  private_subnet_ids        = data.terraform_remote_state.eks.outputs.private_subnet_ids
  public_subnet_ids         = data.terraform_remote_state.eks.outputs.public_subnet_ids
  cluster_security_group_id = data.terraform_remote_state.eks.outputs.cluster_security_group_id
  db_subnet_group_id        = data.terraform_remote_state.shared.outputs.retailstore_elasticache_subnet_group_id
  common_tags = {
    Project     = "RetailStore"
    Environment = var.environment_name
    Division    = var.business_division
    Service     = "Orders"
    ManagedBy   = "Terraform"
    Owner       = var.owner_email

  }
}
