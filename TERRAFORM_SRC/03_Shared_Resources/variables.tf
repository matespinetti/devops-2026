variable "aws_region" {
  description = "The AWS region where resources will be created"
  default     = "us-east-1"
  type        = string

}

variable "business_division" {
  description = "The business division"
  default     = "retail"
  type        = string

}

variable "environment_name" {
  description = "The environment name"
  default     = "dev"
  type        = string

}

variable "domain_name" {
  description = "The domain name"
  default     = ""
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  default     = {}
  type        = map(string)
}
