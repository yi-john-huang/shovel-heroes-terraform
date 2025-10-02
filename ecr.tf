# Amazon ECR (Elastic Container Registry) for Docker images

# ECR repositories for application containers
resource "aws_ecr_repository" "app" {
  for_each = toset(local.ecr_repositories)

  name                 = "${var.project_name}-${local.env_type}-${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true # Scan for vulnerabilities
  }

  encryption_configuration {
    encryption_type = "AES256" # Use KMS for production
  }

  tags = merge(local.common_tags, {
    Name       = "${var.project_name}-${local.env_type}-${each.key}"
    Repository = each.key
  })
}

# Lifecycle policy to clean up old images
resource "aws_ecr_lifecycle_policy" "app" {
  for_each = aws_ecr_repository.app

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${local.is_production ? 30 : 10} images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "release"]
          countType     = "imageCountMoreThan"
          countNumber   = local.is_production ? 30 : 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Remove untagged images after ${local.is_production ? 7 : 1} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = local.is_production ? 7 : 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# IAM policy for pulling images from ECR
resource "aws_iam_policy" "ecr_read" {
  name_prefix = "${var.project_name}-${local.env_type}-ecr-read-"
  description = "Allow pulling images from ECR for ${local.app_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

# IAM policy for pushing images to ECR (for CI/CD)
resource "aws_iam_policy" "ecr_write" {
  name_prefix = "${var.project_name}-${local.env_type}-ecr-write-"
  description = "Allow pushing images to ECR for ${local.app_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}
