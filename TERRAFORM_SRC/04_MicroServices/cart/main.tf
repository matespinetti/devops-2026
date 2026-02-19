# ------------------------------------------------------------------------------
# 1. DYNAMODB TABLE (Serverless Database)
# ------------------------------------------------------------------------------
resource "aws_dynamodb_table" "cart_items_table" {
  name         = "${local.name_prefix}-items"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "customerId"
    type = "S"
  }

  global_secondary_index {
    name            = "idx-global-customer-id"
    projection_type = "ALL"
    hash_key        = "customerId"
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "${local.name_prefix}-items"
  }
}

# ------------------------------------------------------------------------------
# 2. SSM PARAMETERS
# ------------------------------------------------------------------------------
resource "aws_ssm_parameter" "items_table_name" {
  name  = "${local.path_prefix}/items_table_name"
  type  = "String"
  value = aws_dynamodb_table.cart_items_table.name

  tags = {
    Name = "${local.name_prefix}-items-table-name"
  }
}

# ------------------------------------------------------------------------------
# 3. IAM POLICIES
# ------------------------------------------------------------------------------
resource "aws_iam_policy" "dynamodb_policy" {
  name        = "${local.name_prefix}-dynamodb-policy"
  description = "IAM policy for cart service to access its DynamoDB table"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.cart_items_table.arn
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-dynamodb-policy"
  }
}

resource "aws_iam_policy" "ssm_policy" {
  name        = "${local.name_prefix}-ssm-policy"
  description = "IAM policy for cart service to access its SSM Parameter Store"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Effect   = "Allow"
        Resource = aws_ssm_parameter.items_table_name.arn
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-ssm-policy"
  }
}

# ------------------------------------------------------------------------------
# 4. IAM ROLE
# ------------------------------------------------------------------------------
resource "aws_iam_role" "service_role" {
  name = "${local.name_prefix}-role"

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

  tags = {
    Name = "${local.name_prefix}-role"
  }
}

resource "aws_iam_role_policy_attachment" "dynamodb_policy_attachment" {
  policy_arn = aws_iam_policy.dynamodb_policy.arn
  role       = aws_iam_role.service_role.name
}

resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  policy_arn = aws_iam_policy.ssm_policy.arn
  role       = aws_iam_role.service_role.name
}

# ------------------------------------------------------------------------------
# 5. EKS POD IDENTITY ASSOCIATION
# ------------------------------------------------------------------------------
resource "aws_eks_pod_identity_association" "service_pod_identity" {
  cluster_name    = data.terraform_remote_state.eks.outputs.eks_cluster_name
  namespace       = "default"
  service_account = "cart"
  role_arn        = aws_iam_role.service_role.arn

  tags = {
    Name = "${local.name_prefix}-pod-identity-association"
  }
}
