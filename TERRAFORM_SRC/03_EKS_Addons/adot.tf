data "aws_iam_policy_document" "adot_collector_trust_policy" {
  version = "2012-10-17"
  statement {
    sid     = "PodIdentity"
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "adot_collector_policy" {
  name        = "${local.cluster_name}-adot-collector-policy"
  description = "Permission for ADOT collector to write to X-Ray, Cloudwatch and AMP "
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # 1. Traces: Permissions for AWS X-Ray
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets",
          "xray:GetSamplingStatisticSummaries"
        ]
        Resource = "*"
      },
      # 2. Metrics: Permissions for Amazon Managed Prometheus (AMP)
      {
        Effect = "Allow"
        Action = [
          "aps:RemoteWrite",
          "aps:GetSeries",
          "aps:GetLabels",
          "aps:GetMetricMetadata",
          "aps:QueryMetrics"
        ]
        Resource = "*" # Or scope to your specific AMP workspace ARN
      },
      # 3. Logs Permissions for CloudWatch
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/*",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/*:*"
        ]
      },
      # 4. Infrastructure Metadata (Required for the resourcedetection processor)
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },

      #5. Cloudwatch metrics(Wont we used(optional))
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]

  })
}
resource "aws_iam_role" "adot_collector_role" {
  name               = "${local.cluster_name}-adot-collector-role"
  assume_role_policy = data.aws_iam_policy_document.adot_collector_trust_policy.json
}

resource "aws_iam_role_policy_attachment" "adot_collector_policy_attachment" {
  role       = aws_iam_role.adot_collector_role.name
  policy_arn = aws_iam_policy.adot_collector_policy.arn
}

resource "aws_eks_pod_identity_association" "adot_collector" {
  cluster_name    = local.cluster_name
  namespace       = "default"
  service_account = "adot-collector"
  role_arn        = aws_iam_role.adot_collector_role.arn
}


data "aws_eks_addon_version" "adot_latest" {
  addon_name         = "adot"
  kubernetes_version = data.terraform_remote_state.eks.outputs.eks_cluster_version
  most_recent        = true
}

resource "aws_eks_addon" "adot" {
  cluster_name                = local.cluster_name
  addon_name                  = "adot"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  addon_version               = data.aws_eks_addon_version.adot_latest.version

  configuration_values = jsonencode({
    manager = {
      resources = {
        limits = {
          cpu    = "200m"
          memory = "256Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
    }
  })
  depends_on = [
    aws_eks_addon.cert_manager,
    aws_eks_addon.pod_identity_agent,
    helm_release.aws_load_balancer_controller,
    aws_eks_pod_identity_association.adot_collector
  ]
}


resource "kubernetes_service_account" "adot_collector" {
  metadata {
    name      = "adot-collector"
    namespace = "default"
    labels = {
      "app.kubernetes.io/name"      = "adot-collector"
      "app.kubernetes.io/component" = "opentelemetry-collector"
    }
  }
}

resource "kubernetes_cluster_role" "otel_collector_cluster_role" {
  metadata {
    name = "otel-collector-cluster-role"
  }
  rule {
    api_groups = [""]
    resources  = ["pods", "nodes/proxy", "services", "endpoints", "nodes", "namespaces"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["replicasets", "deployments", "daemonsets", "statefulsets"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    non_resource_urls = ["/metrics", "/metrics/cadvisor"]
    verbs             = ["get"]
  }
}


resource "kubernetes_cluster_role_binding" "otel_collector_cluster_role_binding" {
  metadata {
    name = "otel-collector-cluster-role-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.otel_collector_cluster_role.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.adot_collector.metadata[0].name
    namespace = kubernetes_service_account.adot_collector.metadata[0].namespace
  }
}
