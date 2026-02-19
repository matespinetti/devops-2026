
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.8.1"
    }

  }
  backend "s3" {
    bucket       = "tfstate-dev-us-east-1-m75hlh"
    key          = "microservices/orders/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true

  }
}

# Providers
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = local.common_tags
  }
}
provider "random" {
  # Configuration options
}
