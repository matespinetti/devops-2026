output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OpenID Connect provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "ecr_repository_names" {
  description = "Map of service to ECR repository name"
  value = {
    for service, repo in aws_ecr_repository.microservice : service => repo.name
  }
}

output "ecr_repository_urls" {
  description = "Map of service to ECR repository URL"
  value = {
    for service, repo in aws_ecr_repository.microservice : service => repo.repository_url
  }
}

output "github_actions_role_arns" {
  description = "Map of service to GitHub Actions IAM role ARN"
  value = {
    for service, role in aws_iam_role.github_actions_ecr : service => role.arn
  }
}
