output "cart_role_arn" {
  description = "ARN of the cart IAM role"
  value       = aws_iam_role.service_role.arn
}

output "cart_pod_identity_association_id" {
  description = "ID of the cart Pod Identity association"
  value       = aws_eks_pod_identity_association.service_pod_identity.id
}

output "cart_items_table_name_parameter" {
  description = "SSM parameter path for cart items table name"
  value       = aws_ssm_parameter.items_table_name.name
}
