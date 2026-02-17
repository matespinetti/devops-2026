data "http" "load_balancer_controller_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "load_balancer_controller_iam_policy" {
  name        = "${local.name}-load-balancer-controller-iam-policy"
  path        = "/"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = data.http.load_balancer_controller_iam_policy.response_body
}

resource "aws_iam_role" "load_balancer_controller_iam_role" {
  name = "${local.name}-load-balancer-controller-iam-role"
  path = "/"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]

        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "load_balancer_controller_iam_role_policy_attachment" {
  role       = aws_iam_role.load_balancer_controller_iam_role.name
  policy_arn = aws_iam_policy.load_balancer_controller_iam_policy.arn
}




resource "helm_release" "aws_load_balancer_controller" {
  name            = "aws-load-balancer-controller"
  repository      = "https://aws.github.io/eks-charts"
  chart           = "aws-load-balancer-controller"
  version         = "3.0.0"
  namespace       = "kube-system"
  cleanup_on_fail = true

  set = [
    {
      name  = "clusterName"
      value = aws_eks_cluster.main.name
    },
    {
      name  = "region"
      value = var.aws_region
    },
    {
      name  = "serviceAccount.create"
      value = true
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
    {
      name  = "vpcId"
      value = data.terraform_remote_state.vpc.outputs.vpc_id
    }
  ]
  depends_on = [
    aws_iam_role.load_balancer_controller_iam_role,
    aws_eks_node_group.private_nodes,
    aws_eks_pod_identity_association.aws_load_balancer_controller,
    aws_eks_addon.pod_identity_agent
  ]

}
resource "aws_eks_pod_identity_association" "aws_load_balancer_controller" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.load_balancer_controller_iam_role.arn
}
