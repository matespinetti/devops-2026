resource "aws_ecr_repository" "microservice" {
  for_each = var.services

  name                 = "${var.ecr_repository_prefix}${each.key}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  force_delete = false

  tags = {
    Name      = "${var.ecr_repository_prefix}${each.key}"
    Service   = title(each.key)
    Component = "ContainerRegistry"
  }
}

resource "aws_ecr_lifecycle_policy" "microservice" {
  for_each = var.services

  repository = aws_ecr_repository.microservice[each.key].name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the most recent images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.ecr_image_keep_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
