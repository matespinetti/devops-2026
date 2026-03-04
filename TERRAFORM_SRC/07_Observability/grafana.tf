

resource "aws_iam_policy" "amg_prometheus_policy" {
  name        = "${local.name_prefix}-amg-prometheus-policy"
  description = "Policy for AMG Prometheus"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aps:ListWorkspaces",
          "aps:DescribeWorkspace",
          "aps:RemoteWrite",
          "aps:GetSeries",
          "aps:GetLabels",
          "aps:GetMetricMetadata",
          "aps:QueryMetrics"
        ]
        Resource = "*"
      }
    ]
  })
  tags = merge(local.common_tags, {
    Name      = "${local.name_prefix}-amg-prometheus-policy"
    Component = "amg-prometheus"
  })
}

resource "aws_iam_policy" "amg_sns_policy" {
  name        = "${local.name_prefix}-amg-sns-policy"
  description = "Policy for AMG SNS"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:ListTopics",
          "sns:DescribeTopics",
          "sns:Publish"
        ]
        Resource = [
          "arn:aws:sns:*:${data.aws_caller_identity.current.account_id}:grafana*"
        ]
      }
    ]
  })
  tags = merge(local.common_tags, {
    Name      = "${local.name_prefix}-amg-sns-policy"
    Component = "amg-sns"
  })
}

resource "aws_iam_role" "amg_role" {
  name        = "${local.name_prefix}-amg-role"
  description = "IAM role for Amazon Managed Grafana"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "grafana.amazonaws.com"
        }
      }
    ]
  })
  tags = merge(local.common_tags, {
    Name      = "${local.name_prefix}-amg-role"
    Component = "amg-role"
  })
}

resource "aws_iam_role_policy_attachment" "amg_prometheus_policy_attachment" {
  role       = aws_iam_role.amg_role.name
  policy_arn = aws_iam_policy.amg_prometheus_policy.arn
}

resource "aws_iam_role_policy_attachment" "amg_sns_policy_attachment" {
  role       = aws_iam_role.amg_role.name
  policy_arn = aws_iam_policy.amg_sns_policy.arn
}


resource "aws_iam_role_policy_attachment" "amg_xray_readonly_policy_attachment" {
  role       = aws_iam_role.amg_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayReadOnlyAccess"
  depends_on = [aws_iam_role.amg_role]
}
resource "aws_iam_role_policy_attachment" "amg_cloudwatch_readonly" {
  role       = aws_iam_role.amg_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
  depends_on = [aws_iam_role.amg_role]
}


resource "aws_grafana_workspace" "amg" {
  name                     = "${local.name_prefix}-amg"
  description              = "Amazon Managed Grafana workspace for ${local.name_prefix}"
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "CUSTOMER_MANAGED"
  role_arn                 = aws_iam_role.amg_role.arn

  # Data sources that grafana can query
  data_sources = ["PROMETHEUS", "CLOUDWATCH", "XRAY"]

  #Notification destinations

  notification_destinations = ["SNS"]

  #Network access: Open(as of not VPC-restricted)
  # For VPC access, add vpc_configuration block

  configuration = jsonencode(
    {
      "plugins" = {
        "pluginAdminEnabled" = true
      },
      "unifiedAlerting" = {
        "enabled" = true
      }
    }
  )
  tags = merge(local.common_tags, {
    Name      = "${local.name_prefix}-amg"
    Component = "amg"
  })
}
