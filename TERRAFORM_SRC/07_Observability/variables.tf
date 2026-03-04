variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment_name" {
  description = "Environment name used in resource names and tags"
  type        = string
  default     = "dev"
}

variable "business_division" {
  description = "Business division in the organization"
  type        = string
  default     = "retail"
}

variable "project_name" {
  description = "Project or product name for consistent tagging"
  type        = string
  default     = "RetailStore"
}

variable "owner_email" {
  description = "Owner contact used for operations and cost attribution"
  type        = string
  default     = "platform@example.com"
}

variable "tags" {
  description = "Extra tags to merge into standard platform tags"
  type        = map(string)
  default = {
    Terraform = "true"
  }
}
