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

variable "owner_email" {
  description = "Owner email"
  type        = string
  default     = "mateospinetti1@gmail.com"
}

variable "db_user" {
  description = "Database username"
  type        = string
  default     = "orders"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "orders"
}
