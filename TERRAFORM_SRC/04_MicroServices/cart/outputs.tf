output "cart_role_arn" {
  value       = aws_iam_role.cart_role.arn
  description = "Cart role ARN"
}

output "cart_pod_identity_association_id" {
  value       = aws_eks_pod_identity_association.cart.id
  description = "Cart pod identity association ID"
}

output "cart_ssm_param_items_table_name" {
  value       = aws_ssm_parameter.cart_items_table_name.name
  description = "Path to the param"
}
