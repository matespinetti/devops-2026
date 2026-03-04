# 08_CICD

This stack manages CI/CD account-level resources for GitHub Actions and ECR:

- GitHub OIDC identity provider in IAM
- One ECR repository per microservice
- One GitHub Actions IAM role per microservice repo/branch with least-privilege ECR push permissions

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

## Outputs used by GitHub Actions

- `github_actions_role_arns`
- `ecr_repository_urls`
