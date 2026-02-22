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

variable "tags" {
  description = "Tags to apply to addon resources"
  type        = map(string)
  default = {
    Terraform = "true"
  }
}
