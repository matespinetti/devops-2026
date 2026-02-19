data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "tfstate-dev-us-east-1-m75hlh"
    key    = "eks/dev/terraform.tfstate"
    region = var.aws_region
  }
}

data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "tfstate-dev-us-east-1-m75hlh"
    key    = "shared/dev/terraform.tfstate"
    region = var.aws_region
  }
}

locals {
  service_name = "checkout"
  name_prefix  = "${var.business_division}-${var.environment_name}-${local.service_name}"
  path_prefix  = "/${var.business_division}/${var.environment_name}/${local.service_name}"

  vpc_id                    = data.terraform_remote_state.eks.outputs.vpc_id
  private_subnet_ids        = data.terraform_remote_state.eks.outputs.private_subnet_ids
  public_subnet_ids         = data.terraform_remote_state.eks.outputs.public_subnet_ids
  cluster_security_group_id = data.terraform_remote_state.eks.outputs.cluster_security_group_id
  db_subnet_group_id        = data.terraform_remote_state.shared.outputs.retailstore_elasticache_subnet_group_id

  common_tags = {
    Project     = "RetailStore"
    Environment = var.environment_name
    Division    = var.business_division
    Service     = "Checkout"
    ManagedBy   = "Terraform"
    Owner       = var.owner_email
  }
}
