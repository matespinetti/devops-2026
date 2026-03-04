locals {
  service_name = "monitoring"
  owners       = var.business_division
  environment  = var.environment_name
  name         = "${local.owners}-${local.environment}"
  name_prefix  = "${local.name}-${local.service_name}"
  cluster_name = data.terraform_remote_state.eks.outputs.eks_cluster_name
  account_id   = data.aws_caller_identity.current.account_id
  region       = data.aws_region.current.name

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment_name
      Division    = var.business_division
      Service     = "Monitoring"
      ManagedBy   = "Terraform"
      Owner       = var.owner_email
      Stack       = "07_Observability"
    },
    var.tags
  )
}
