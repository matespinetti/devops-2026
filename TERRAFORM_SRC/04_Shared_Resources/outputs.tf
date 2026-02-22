output "retailstore_rds_subnet_group_id" {
  value = aws_db_subnet_group.retailstore_rds_main.id
}

output "retailstore_elasticache_subnet_group_id" {
  value = aws_elasticache_subnet_group.retailstore_elasticache_main.id
}

output "retailstore_acm_certificate_arn" {
  value = aws_acm_certificate.main.arn
}

output "retailstore_db_secret_policy_arn" {
  value = aws_iam_policy.retailstore_db_secret_policy.arn
}
