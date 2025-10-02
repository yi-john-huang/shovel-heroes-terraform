# Customer-managed KMS keys for encryption at rest

# KMS key for RDS encryption
resource "aws_kms_key" "rds" {
  count = local.rds_enabled ? 1 : 0

  description             = "KMS key for RDS database encryption"
  deletion_window_in_days = local.is_production ? 30 : 7
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${local.env_type}-rds-kms"
    Purpose = "RDS encryption"
  })
}

resource "aws_kms_alias" "rds" {
  count = local.rds_enabled ? 1 : 0

  name          = "alias/${var.project_name}-${local.env_type}-rds"
  target_key_id = aws_kms_key.rds[0].key_id
}

# KMS key for S3 encryption
resource "aws_kms_key" "s3" {
  count = local.s3_enabled ? 1 : 0

  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = local.is_production ? 30 : 7
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${local.env_type}-s3-kms"
    Purpose = "S3 encryption"
  })
}

resource "aws_kms_alias" "s3" {
  count = local.s3_enabled ? 1 : 0

  name          = "alias/${var.project_name}-${local.env_type}-s3"
  target_key_id = aws_kms_key.s3[0].key_id
}

# KMS key for Secrets Manager encryption
resource "aws_kms_key" "secrets" {
  description             = "KMS key for Secrets Manager encryption"
  deletion_window_in_days = local.is_production ? 30 : 7
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${local.env_type}-secrets-kms"
    Purpose = "Secrets Manager encryption"
  })
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project_name}-${local.env_type}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

# KMS key policy for Secrets Manager
resource "aws_kms_key_policy" "secrets" {
  key_id = aws_kms_key.secrets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = aws_kms_key.secrets.arn
      },
      {
        Sid    = "Allow Secrets Manager to use the key"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.secrets.arn
      }
    ]
  })
}
