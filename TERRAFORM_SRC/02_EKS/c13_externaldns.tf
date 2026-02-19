resource "aws_iam_policy" "externaldns_policy" {
  name        = "externaldns-policy"
  description = "Permite a ExternalDNS gestionar registros en Route 53"

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
}

resource "aws_iam_role_policy_attachment" "externaldns_policy_attachment" {
  policy_arn = aws_iam_policy.externaldns_policy.arn
  role       = aws_iam_role.externaldns_role.name
}

resource "aws_eks_pod_identity_association" "externaldns_pod_identity_association" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "kube-system"
  service_account = "external-dns"
  role_arn        = aws_iam_role.externaldns_role.arn
}


resource "helm_release" "external_sdns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "1.20.0"

  set = [{
    name  = "provider",
    value = "aws"
    },
    {
      name  = "serviceAccount.name",
      value = "external-dns"
    },
    # Importante: Esto evita que ExternalDNS borre registros que no creó él
    {
      name  = "policy"
      value = "sync" # 'upsert-only' si tienes miedo de que borre algo
    }
  ]
}
