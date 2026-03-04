data "aws_eks_addon_version" "prometheus_node_exporter_latest" {
  addon_name         = "prometheus-node-exporter"
  kubernetes_version = data.terraform_remote_state.eks.outputs.eks_cluster_version
  most_recent        = true
}

resource "aws_eks_addon" "prometheus_node_exporter" {
  cluster_name                = local.cluster_name
  addon_name                  = "prometheus-node-exporter"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  addon_version               = data.aws_eks_addon_version.prometheus_node_exporter_latest.version
}
