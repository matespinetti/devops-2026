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

