

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "tfstate-dev-us-east-1-m75hlh"
    key    = "eks/dev/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  name = "${var.business_division}-${var.environment_name}-cart"
  common_tags = {
    Project     = "RetailStore"
    Environment = var.environment_name
    Division    = var.business_division
    Service     = "Cart"
    ManagedBy   = "Terraform"
    Owner       = var.owner_email

  }
}
