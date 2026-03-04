resource "aws_eks_addon" "vpc_cni" {
  cluster_name = local.cluster_name
  addon_name   = "vpc-cni"

  configuration_values = jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"
    }
  })
}
