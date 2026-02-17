

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
  vpc_id                    = data.terraform_remote_state.eks.outputs.vpc_id
  private_subnet_ids        = data.terraform_remote_state.eks.outputs.private_subnet_ids
  public_subnet_ids         = data.terraform_remote_state.eks.outputs.public_subnet_ids
  cluster_security_group_id = data.terraform_remote_state.eks.outputs.cluster_security_group_id
  db_subnet_group_id        = data.terraform_remote_state.shared.outputs.db_subnet_group_id
  name                      = "${var.environment_name}-${var.business_division}"
  tags                      = var.tags
}
