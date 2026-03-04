locals {
  owners      = var.business_division
  environment = var.environment_name
  name        = "${local.owners}-${local.environment}"
  name_prefix = "${local.name}-cicd"

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment_name
      Division    = var.business_division
      Service     = "CICD"
      ManagedBy   = "Terraform"
      Owner       = var.owner_email
      Stack       = "08_CICD"
    },
    var.tags
  )
}
