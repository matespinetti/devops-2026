locals {
  owners       = var.business_division
  environment  = var.environment_name
  name         = "${local.owners}-${local.environment}"
  cluster_name = data.terraform_remote_state.eks.outputs.eks_cluster_name
}
