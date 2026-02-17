resource "helm_release" "secrets_csi_driver" {
  name       = "csi-secrets-store"
  chart      = "secrets-store-csi-driver"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  namespace  = "kube-system"


  set = [
    {
      name  = "syncSecret.enabled"
      value = "true"
    }
  ]
  depends_on = [
    aws_eks_cluster.main
  ]
}

resource "helm_release" "secrets_provider_aws" {
  name       = "secrets-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  namespace  = "kube-system"

  set = [
    {
      name  = "secrets-store-csi-driver.install"
      value = "false"
    }
  ]
  depends_on = [
    helm_release.secrets_csi_driver
  ]
}
