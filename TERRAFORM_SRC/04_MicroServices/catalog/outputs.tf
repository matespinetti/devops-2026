output "catalog_secret_arn" {
  value = aws_secretsmanager_secret.catalog_config.arn

}
output "catalog_db_arn" {
  value = module.rds.db_instance_arn
}

output "catalog_db_endpoint" {
  value = module.rds.db_instance_endpoint
}

output "catalog_role_arn" {
  value = aws_iam_role.catalog_role.arn
}
