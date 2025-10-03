# GitHub Actions OIDC Provider and IAM Role
# Allows GitHub Actions workflows to authenticate to AWS without storing credentials

# Get GitHub OIDC thumbprint
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# OIDC provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.env_type}-github-oidc-provider"
  })
}

# IAM role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name_prefix = "${var.project_name}-${local.env_type}-github-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # Restrict to specific repository
          "token.actions.githubusercontent.com:sub" = "repo:yi-john-huang/shovel-heroes-k8s:*"
        }
      }
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.env_type}-github-actions-role"
  })
}

# Attach ECR write policy for pushing container images
resource "aws_iam_role_policy_attachment" "github_actions_ecr" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.ecr_write.arn
}

# EKS access policy for kubectl operations
resource "aws_iam_role_policy" "github_actions_eks" {
  name = "eks-access"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "eks:DescribeCluster",
        "eks:ListClusters",
        "eks:AccessKubernetesApi"
      ]
      Resource = local.eks_enabled ? module.eks[0].cluster_arn : "*"
    }]
  })
}

# Secrets Manager read policy for accessing secrets in workflows
resource "aws_iam_role_policy" "github_actions_secrets" {
  name = "secrets-read"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = local.rds_enabled ? [
        aws_secretsmanager_secret.database[0].arn,
        aws_secretsmanager_secret.application.arn,
        aws_secretsmanager_secret.jwt.arn
        ] : [
        aws_secretsmanager_secret.application.arn,
        aws_secretsmanager_secret.jwt.arn
      ]
    }]
  })
}
