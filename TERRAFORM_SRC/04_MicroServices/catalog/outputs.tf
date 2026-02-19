output "catalog_secret_arn" {
  description = "ARN of the catalog secret"
  value       = aws_secretsmanager_secret.catalog_secrets.arn
}

output "catalog_db_arn" {
  description = "ARN of the catalog RDS instance"
  value       = module.catalog_db.db_instance_arn
}

output "catalog_db_endpoint" {
  description = "Endpoint of the catalog RDS instance"
  value       = module.catalog_db.db_instance_endpoint
}

output "catalog_role_arn" {
  description = "ARN of the catalog IAM role"
  value       = aws_iam_role.service_role.arn
}
