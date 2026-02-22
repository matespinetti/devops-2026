resource "aws_iam_policy" "externaldns_policy" {
  name        = "externaldns-policy"
  description = "Allows ExternalDNS to manage Route53 records"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets"]
        Resource = ["arn:aws:route53:::hostedzone/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource"
        ]
        Resource = ["*"]
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role" "externaldns_role" {
  name = "externaldns-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["sts:AssumeRole", "sts:TagSession"]
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "externaldns_policy_attachment" {
  policy_arn = aws_iam_policy.externaldns_policy.arn
  role       = aws_iam_role.externaldns_role.name
}

resource "aws_eks_pod_identity_association" "externaldns_pod_identity_association" {
  cluster_name    = data.terraform_remote_state.eks.outputs.eks_cluster_name
  namespace       = "kube-system"
  service_account = "external-dns"
  role_arn        = aws_iam_role.externaldns_role.arn

  depends_on = [aws_eks_addon.pod_identity_agent]
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "1.20.0"

  set = [
    {
      name  = "provider"
      value = "aws"
    },
    {
      name  = "serviceAccount.name"
      value = "external-dns"
    },
    {
      name  = "policy"
      value = "sync"
    }
  ]

  depends_on = [
    aws_eks_pod_identity_association.externaldns_pod_identity_association,
    aws_eks_addon.pod_identity_agent
  ]
}
