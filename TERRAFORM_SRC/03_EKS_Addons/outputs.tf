output "pod_identity_agent_version" {
  description = "Installed version for EKS Pod Identity Agent"
  value       = aws_eks_addon.pod_identity_agent.addon_version
}

output "ebs_csi_driver_role_arn" {
  description = "IAM role ARN used by EBS CSI driver"
  value       = aws_iam_role.ebs_csi_driver_role.arn
}

output "load_balancer_controller_role_arn" {
  description = "IAM role ARN used by AWS Load Balancer Controller"
  value       = aws_iam_role.load_balancer_controller_iam_role.arn
}

output "externaldns_role_arn" {
  description = "IAM role ARN used by ExternalDNS"
  value       = aws_iam_role.externaldns_role.arn
}
