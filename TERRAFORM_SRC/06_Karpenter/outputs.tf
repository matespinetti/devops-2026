output "karpenter_controller_role_arn" {
  value = aws_iam_role.karpenter_controller_role.arn
}

output "karpenter_node_role_arn" {
  value = aws_iam_role.karpenter_node_role.arn
}

output "karpenter_interruptions_queue_name" {
  value = aws_sqs_queue.karpenter_interruptions_queue.name
}

output "karpenter_interruptions_queue_url" {
  value = aws_sqs_queue.karpenter_interruptions_queue.url
}
