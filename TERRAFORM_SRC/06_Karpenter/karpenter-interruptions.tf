resource "aws_sqs_queue" "karpenter_interruptions_queue" {
  name                      = "${local.name_prefix}-karpenter-interruptions-queue"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
  tags = {
    Name = "${local.name_prefix}-karpenter-interruptions-queue"
  }
}
resource "aws_sqs_queue_policy" "karpenter_interruptions_queue_policy" {
  queue_url = aws_sqs_queue.karpenter_interruptions_queue.url
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSQSAndEvents"
        Effect = "Allow"
        Principal = {
          Service = ["sqs.amazonaws.com", "events.amazonaws.com"]
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.karpenter_interruptions_queue.arn
      },
      {
        Sid      = "DenyNonHTTPS"
        Effect   = "Deny",
        Action   = "sqs:*"
        Resource = aws_sqs_queue.karpenter_interruptions_queue.arn
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }

        }
        Principal = "*"
      }
    ]
  })
}

# 1. AWS Health Event (Scheduled maintenance)

resource "aws_cloudwatch_event_rule" "karpenter_health_event_rule" {
  name        = "${local.name_prefix}-karpenter-health-event-rule"
  description = "AWS Health Event -> Karpenter Interruption Notification"
  event_pattern = jsonencode({
    source      = ["aws.health"]
    detail-type = ["AWS Health Event"]
    detail = {
      service           = ["ec2"]
      eventTypeCategory = ["scheduledChange"]
    }
  })
}


resource "aws_cloudwatch_event_target" "karpenter_health_event_target" {
  rule      = aws_cloudwatch_event_rule.karpenter_health_event_rule.name
  target_id = "KarpenterHealthQueueTarget"
  arn       = aws_sqs_queue.karpenter_interruptions_queue.arn
}


#2. Spot Instance Interruption Warning (2 minutes warning)

resource "aws_cloudwatch_event_rule" "karpenter_spot_interruption_rule" {
  name        = "${local.name_prefix}-karpenter-spot-interruption-rule"
  description = "Spot Instance Interruption Warning (2 minutes warning)"
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_spot_interruption_target" {
  rule      = aws_cloudwatch_event_rule.karpenter_spot_interruption_rule.name
  target_id = "KarpenterSpotQueueTarget"
  arn       = aws_sqs_queue.karpenter_interruptions_queue.arn
}


#3. EC2 Instance Rebalance Recommendation

resource "aws_cloudwatch_event_rule" "karpenter_rebalance_recommendation_rule" {
  name        = "${local.name_prefix}-karpenter-rebalance-recommendation-rule"
  description = "EC2 Instance Rebalance Recommendation -> Karpenter Interruption Notification"
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_rebalance_recommendation_target" {
  rule      = aws_cloudwatch_event_rule.karpenter_rebalance_recommendation_rule.name
  target_id = "KarpenterRebalanceQueueTarget"
  arn       = aws_sqs_queue.karpenter_interruptions_queue.arn
}


#4. EC2 Instance State-Change Notification
resource "aws_cloudwatch_event_rule" "karpenter_state_change_rule" {
  name        = "${local.name_prefix}-karpenter-state-change-rule"
  description = "EC2 Instance State-Change Notification -> Karpenter Interruption Notification"
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-Change Notification"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_state_change_target" {
  rule      = aws_cloudwatch_event_rule.karpenter_state_change_rule.name
  target_id = "KarpenterStateChangeQueueTarget"
  arn       = aws_sqs_queue.karpenter_interruptions_queue.arn
}
