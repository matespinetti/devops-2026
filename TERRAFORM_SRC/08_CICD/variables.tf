variable "aws_region" {
  description = "AWS region where CICD resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "business_division" {
  description = "Business or project domain"
  type        = string
  default     = "retail"
}

variable "environment_name" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project or product name for consistent tagging"
  type        = string
  default     = "RetailStore"
}

variable "owner_email" {
  description = "Owner contact for operations and cost attribution"
  type        = string
  default     = "platform@example.com"
}

variable "github_organization" {
  description = "GitHub organization/user that owns the microservice repos"
  type        = string
}

variable "services" {
  description = "Service map keyed by service name with the owning repo and deployment branch"
  type = map(object({
    repo_name = string
    branch    = string
  }))
  default = {
    cart = {
      repo_name = "cart"
      branch    = "main"
    }
    catalog = {
      repo_name = "catalog"
      branch    = "main"
    }
    checkout = {
      repo_name = "checkout"
      branch    = "main"
    }
    orders = {
      repo_name = "orders"
      branch    = "main"
    }
    ui = {
      repo_name = "ui"
      branch    = "main"
    }
  }
}

variable "ecr_repository_prefix" {
  description = "Prefix used when creating service-specific ECR repositories"
  type        = string
  default     = "retail-dev-"
}

variable "ecr_image_keep_count" {
  description = "Number of most recent images to keep in each ECR repository"
  type        = number
  default     = 50
}

variable "tags" {
  description = "Extra tags to merge into standard platform tags"
  type        = map(string)
  default = {
    Terraform = "true"
  }
}
