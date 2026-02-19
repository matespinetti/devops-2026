output "checkout_role_arn" {
  description = "ARN of the checkout IAM role"
  value       = aws_iam_role.service_role.arn
}

output "checkout_redis_host_parameter" {
  description = "SSM parameter path for checkout redis host"
  value       = aws_ssm_parameter.redis_host.name
}

output "checkout_redis_port_parameter" {
  description = "SSM parameter path for checkout redis port"
  value       = aws_ssm_parameter.redis_port.name
}
