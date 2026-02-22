resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name                = data.terraform_remote_state.eks.outputs.eks_cluster_name
  addon_name                  = "eks-pod-identity-agent"
  addon_version               = data.aws_eks_addon_version.pia_latest.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}
