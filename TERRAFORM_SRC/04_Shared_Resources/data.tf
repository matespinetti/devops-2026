data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "tfstate-dev-us-east-1-m75hlh"
    key    = "vpc/dev/terraform.tfstate"
    region = "us-east-1"
  }
}

data "aws_route53_zone" "main" {
  name = "${var.domain_name}."
}

data "aws_caller_identity" "current" {}

locals {
  private_subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids
  name               = "${var.business_division}-${var.environment_name}"
}
