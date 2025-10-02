# IAM roles for Shovel Heroes application

# OIDC provider data for EKS (for IRSA - IAM Roles for Service Accounts)
data "aws_iam_policy_document" "backend_assume_role" {
  count = local.eks_enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(module.eks[0].cluster_oidc_issuer_url, "https://", "")}"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks[0].cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${local.app_name}:${local.app_name}-backend"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks[0].cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# IAM role for backend pods (IRSA)
resource "aws_iam_role" "backend_pods" {
  count = local.eks_enabled ? 1 : 0

  name_prefix        = "${var.project_name}-${local.env_type}-backend-"
  assume_role_policy = data.aws_iam_policy_document.backend_assume_role[0].json

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.env_type}-backend-pods-role"
  })
}

# Attach secrets read policy to backend role
resource "aws_iam_role_policy_attachment" "backend_secrets" {
  count = local.eks_enabled ? 1 : 0

  role       = aws_iam_role.backend_pods[0].name
  policy_arn = aws_iam_policy.secrets_read.arn
}

# Attach ECR read policy to backend role
resource "aws_iam_role_policy_attachment" "backend_ecr_read" {
  count = local.eks_enabled ? 1 : 0

  role       = aws_iam_role.backend_pods[0].name
  policy_arn = aws_iam_policy.ecr_read.arn
}

# CloudWatch Logs policy for backend
resource "aws_iam_policy" "backend_cloudwatch" {
  count = local.eks_enabled ? 1 : 0

  name_prefix = "${var.project_name}-${local.env_type}-backend-cw-"
  description = "Allow backend pods to write to CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${local.eks_cluster_name}/*",
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/application/${var.project_name}-${local.env_type}/*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "backend_cloudwatch" {
  count = local.eks_enabled ? 1 : 0

  role       = aws_iam_role.backend_pods[0].name
  policy_arn = aws_iam_policy.backend_cloudwatch[0].arn
}

# S3 access policy for application (uploads, backups, etc.)
resource "aws_iam_policy" "backend_s3" {
  count = local.eks_enabled && local.s3_enabled ? 1 : 0

  name_prefix = "${var.project_name}-${local.env_type}-backend-s3-"
  description = "Allow backend pods to access S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.logs[0].arn,
          aws_s3_bucket.backups[0].arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.logs[0].arn}/*",
          "${aws_s3_bucket.backups[0].arn}/*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "backend_s3" {
  count = local.eks_enabled && local.s3_enabled ? 1 : 0

  role       = aws_iam_role.backend_pods[0].name
  policy_arn = aws_iam_policy.backend_s3[0].arn
}

# IAM role for GitHub Actions OIDC
# This allows GitHub Actions to assume AWS roles without storing credentials
resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1", # GitHub Actions OIDC thumbprint
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"  # Backup thumbprint
  ]

  tags = local.common_tags
}

# IAM role for GitHub Actions to deploy
resource "aws_iam_role" "github_actions" {
  name_prefix = "${var.project_name}-${local.env_type}-github-actions-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Adjust this to match your GitHub org/repo
            # Format: "repo:OWNER/REPO:*"
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/*:*"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.env_type}-github-actions-role"
  })
}

# Attach ECR write policy to GitHub Actions role
resource "aws_iam_role_policy_attachment" "github_actions_ecr_write" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.ecr_write.arn
}

# Policy for GitHub Actions to deploy to EKS
resource "aws_iam_policy" "github_actions_eks" {
  count = local.eks_enabled ? 1 : 0

  name_prefix = "${var.project_name}-${local.env_type}-github-eks-"
  description = "Allow GitHub Actions to deploy to EKS cluster"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = module.eks[0].cluster_arn
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "github_actions_eks" {
  count = local.eks_enabled ? 1 : 0

  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_eks[0].arn
}

# Policy for GitHub Actions to deploy frontend to S3
resource "aws_iam_policy" "github_actions_s3_frontend" {
  count = local.s3_enabled ? 1 : 0

  name_prefix = "${var.project_name}-${local.env_type}-github-s3-"
  description = "Allow GitHub Actions to deploy frontend to S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.frontend[0].arn,
          "${aws_s3_bucket.frontend[0].arn}/*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "github_actions_s3_frontend" {
  count = local.s3_enabled ? 1 : 0

  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_s3_frontend[0].arn
}

# Policy for GitHub Actions to invalidate CloudFront
resource "aws_iam_policy" "github_actions_cloudfront" {
  count = local.cloudfront_enabled ? 1 : 0

  name_prefix = "${var.project_name}-${local.env_type}-github-cf-"
  description = "Allow GitHub Actions to invalidate CloudFront cache"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "github_actions_cloudfront" {
  count = local.cloudfront_enabled ? 1 : 0

  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_cloudfront[0].arn
}
