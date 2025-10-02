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
          "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/eks-${var.project_name}/*",
          "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/application/${var.project_name}-${local.env_type}/*"
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

