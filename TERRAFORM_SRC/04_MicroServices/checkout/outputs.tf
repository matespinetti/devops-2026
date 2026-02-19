output "checkout_role_arn" {
  value       = aws_iam_role.checkout_role.arn
  description = "ARN of the checkout Role"
}

output "checkout_ssm_param_redis_name" {
  description = "Path to the param"
  value       = aws_ssm_parameter.redis_host.name
}

output "checkout_ssm_param_redis_port" {
  description = "Path to the param"
  value       = aws_ssm_parameter.redis_port.name
}
