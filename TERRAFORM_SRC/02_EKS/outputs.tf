output "eks_cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_id" {
  description = "The name/id of the EKS cluster"
  value       = aws_eks_cluster.main.id
}

output "eks_cluster_version" {
  description = "EKS Kubernetes version"
  value       = aws_eks_cluster.main.version
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64 encoded CA certificate for kubectl config"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "private_node_group_name" {
  description = "Name of the EKS private node group"
  value       = aws_eks_node_group.private_nodes.node_group_name
}

output "eks_node_instance_role_arn" {
  description = "IAM Role ARN used by EKS node group (EC2 worker nodes)"
  value       = aws_iam_role.eks_nodegroup_role.arn
}

output "to_configure_kubectl" {
  description = "Command to update local kubeconfig to connect to the EKS cluster"
  value       = "aws eks --region ${var.aws_region} update-kubeconfig --name ${local.eks_cluster_name}"
}

output "cluster_security_group_id" {
  description = "The security group attached to both control plane and worker nodes"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "vpc_id" {
  description = "VPC ID from remote state"
  value       = data.terraform_remote_state.vpc.outputs.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs from remote state"
  value       = data.terraform_remote_state.vpc.outputs.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs from remote state"
  value       = data.terraform_remote_state.vpc.outputs.public_subnet_ids
}
