data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "tfstate-dev-us-east-1-m75hlh"
    key    = "eks/dev/terraform.tfstate"
    region = var.aws_region
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  name_prefix = "${var.business_division}-${var.environment_name}"
  path_prefix = "/${var.business_division}/${var.environment_name}"

  vpc_id = data.terraform_remote_state.eks.outputs.vpc_id

  cluster_name = data.terraform_remote_state.eks.outputs.eks_cluster_name


  common_tags = {
    Environment = var.environment_name
    Division    = var.business_division
    ManagedBy   = "Terraform"
    Owner       = var.owner_email
  }
}
