resource "aws_iam_openid_connect_provider" "github" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  url             = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  for_each = var.services

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_organization}/${each.value.repo_name}:ref:refs/heads/${each.value.branch}"
      ]
    }
  }
}

resource "aws_iam_role" "github_actions_ecr" {
  for_each = var.services

  name               = "${local.name_prefix}-${each.key}-gha-ecr-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role[each.key].json

  tags = {
    Name      = "${local.name_prefix}-${each.key}-gha-ecr-role"
    Service   = title(each.key)
    Workload  = "GitHubActions"
    Component = "CICD"
  }
}

data "aws_iam_policy_document" "github_actions_ecr_push" {
  for_each = var.services

  statement {
    sid    = "AllowGetECRAuthToken"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowPushPullOnServiceRepository"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = [aws_ecr_repository.microservice[each.key].arn]
  }
}

resource "aws_iam_policy" "github_actions_ecr_push" {
  for_each = var.services

  name        = "${local.name_prefix}-${each.key}-gha-ecr-push-policy"
  description = "Allow GitHub Actions to push/pull images for ${each.key}"
  policy      = data.aws_iam_policy_document.github_actions_ecr_push[each.key].json

  tags = {
    Name      = "${local.name_prefix}-${each.key}-gha-ecr-push-policy"
    Service   = title(each.key)
    Workload  = "GitHubActions"
    Component = "CICD"
  }
}

resource "aws_iam_role_policy_attachment" "github_actions_ecr_push" {
  for_each = var.services

  role       = aws_iam_role.github_actions_ecr[each.key].name
  policy_arn = aws_iam_policy.github_actions_ecr_push[each.key].arn
}
