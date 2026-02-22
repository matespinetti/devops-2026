locals {
  owners      = var.business_division
  environment = var.environment_name
  name        = "${local.owners}-${local.environment}"
}
