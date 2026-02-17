variable "aws_region" {
  type    = string
  default = "us-east-1"
}
# --------------------------------------------------------
# Environment & Business Division Info
# --------------------------------------------------------

# Logical environment name (used in tags and resource names)
variable "environment_name" {
  description = "Environment name used in resource names and tags"
  type        = string
  default     = "dev"
}

# Business unit or department (used in tags and naming)
variable "business_division" {
  description = "Business Division in the large organization this infrastructure belongs to"
  type        = string
  default     = "retail"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "catalogdb"
}

variable "db_username" {
  description = "Database username"
  type        = string

}

variable "db_password" {
  description = "Database password"
  type        = string

}


variable "tags" {
  description = "Tags to apply to EKS and related resources"
  type        = map(string)
  default = {
    Terraform = "true"
  }
}
