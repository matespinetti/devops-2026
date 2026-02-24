resource "helm_release" "karpenter" {
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  namespace        = "kube-system"
  create_namespace = false
  version          = "1.9.0"
  set = [{
    name  = "settings.clusterName"
    value = local.cluster_name
    },
    {
      name  = "settings.clusterEndpoint"
      value = data.terraform_remote_state.eks.outputs.eks_cluster_endpoint

    },
    {
      name  = "settings.interruptionQueue"
      value = aws_sqs_queue.karpenter_interruptions_queue.name
    },
    {
      name  = "serviceAccount.create"
      value = true
    },
    {
      name  = "serviceAccount.name"
      value = "karpenter"
    }
  ]

  depends_on = [
    aws_iam_role_policy_attachment.karpenter_controller_policy_attachment,
    aws_eks_pod_identity_association.karpenter_controller_pod_identity_association,
    aws_eks_access_entry.karpenter_node_access_entry,
    aws_sqs_queue.karpenter_interruptions_queue
  ]

}
