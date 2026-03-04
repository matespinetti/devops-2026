data "aws_eks_addon_version" "cert_manager_latest" {
  addon_name         = "cert-manager"
  kubernetes_version = data.terraform_remote_state.eks.outputs.eks_cluster_version
  most_recent        = true
}


resource "aws_eks_addon" "cert_manager" {
  cluster_name                = local.cluster_name
  addon_name                  = "cert-manager"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  addon_version               = data.aws_eks_addon_version.cert_manager_latest.version
}

