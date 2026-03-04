data "aws_eks_addon_version" "kube_state_metrics_latest" {
  addon_name         = "kube-state-metrics"
  kubernetes_version = data.terraform_remote_state.eks.outputs.eks_cluster_version
  most_recent        = true
}

resource "aws_eks_addon" "kube_state_metrics" {
  cluster_name                = local.cluster_name
  addon_name                  = "kube-state-metrics"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  addon_version               = data.aws_eks_addon_version.kube_state_metrics_latest.version

}
