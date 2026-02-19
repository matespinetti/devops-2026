# ------------------------------------------------------------------------------
# 1. DYNAMODB TABLE (Serverless Database)
# ------------------------------------------------------------------------------
resource "aws_dynamodb_table" "items" {
  name         = "${local.name}-items"
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
  #Global Secondary Index for customer-based lookups
  global_secondary_index {
    name            = "idx_global_customerId"
    projection_type = "ALL"
    hash_key        = "customerId"
  }

  server_side_encryption {
    enabled = true
  }


  tags = {
    Name = "${local.name}-items"
  }
}

# ------------------------------------------------------------------------------
# 2. SSM PARAMETERS
# ------------------------------------------------------------------------------

resource "aws_ssm_parameter" "cart_items_table_name" {
  name  = "${var.business_division}/${var.environment_name}/cart/items_table_name"
  type  = "String"
  value = aws_dynamodb_table.items.name
  tags = {
    Name = "${local.name}-items-table-name"
  }
}

# ------------------------------------------------------------------------------
# 3. IAM POLICIES (Least Privilege - Solo acceso a ESTA tabla)
# ------------------------------------------------------------------------------

# A. Access to DynamoDB table
resource "aws_iam_policy" "cart_dynamodb_policy" {
  name        = "${local.name}-dynamodb-policy"
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
        Resource = aws_dynamodb_table.items.arn
      }
    ]
  })
}

# B. Access to SSM Parameter Store
resource "aws_iam_policy" "cart_ssm_policy" {
  name        = "${local.name}-ssm-policy"
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
        Resource = aws_ssm_parameter.cart_items_table_name.arn
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# 4. IAM ROLE
# ------------------------------------------------------------------------------
resource "aws_iam_role" "cart_role" {
  name = "cart_role"
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
    Name = "${local.name}-role"
  }
}

resource "aws_iam_role_policy_attachment" "cart_dynamodb_policy_attachment" {
  policy_arn = aws_iam_policy.cart_dynamodb_policy.arn
  role       = aws_iam_role.cart_role.name
}

resource "aws_iam_role_policy_attachment" "cart_ssm_policy_attachment" {
  policy_arn = aws_iam_policy.cart_ssm_policy.arn
  role       = aws_iam_role.cart_role.name
}

# ------------------------------------------------------------------------------
# 5. EKS POD IDENTITY ASSOCIATION
# ------------------------------------------------------------------------------
resource "aws_eks_pod_identity_association" "cart" {
  cluster_name    = data.terraform_remote_state.eks.outputs.cluster_name
  namespace       = "default"
  service_account = "cart"
  role_arn        = aws_iam_role.cart_role.arn
  tags = {
    Name = "${local.name}-pod-identity-association"
  }
}




