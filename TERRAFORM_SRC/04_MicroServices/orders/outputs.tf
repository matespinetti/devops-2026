output "orders_role_arn" {
  description = "ARN of the orders IAM role"
  value       = aws_iam_role.service_role.arn
}

output "orders_secret_name" {
  description = "Secrets Manager name for orders service config"
  value       = aws_secretsmanager_secret.orders_secrets.name
}

output "orders_queue_url" {
  description = "SQS queue URL for orders service"
  value       = aws_sqs_queue.queue.url
}

output "orders_db_endpoint" {
  description = "Endpoint of the orders RDS instance"
  value       = module.orders_db.db_instance_endpoint
}
