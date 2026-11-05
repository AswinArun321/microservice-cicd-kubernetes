resource "aws_ecr_repository" "services" {
  for_each             = toset(var.repository_names)
  name                 = each.value
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Service     = each.value
    Environment = var.environment
  }
}

resource "aws_ecr_lifecycle_policy" "services" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Retain maximum ${var.keep_last_image_count} tagged images to manage storage costs"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["sha-", "v", "rel-", "master-"]
          countType     = "imageCountMoreThan"
          countNumber   = var.keep_last_image_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

