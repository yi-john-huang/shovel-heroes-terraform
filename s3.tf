# S3 buckets for Shovel Heroes application

# Random suffix for unique bucket names
resource "random_string" "bucket_suffix" {
  count = local.s3_enabled ? 1 : 0

  length  = 8
  special = false
  upper   = false
}

## Backups Bucket

resource "aws_s3_bucket" "backups" {
  count = local.s3_enabled ? 1 : 0

  bucket = "${local.backup_bucket_name}-${random_string.bucket_suffix[0].result}"

  tags = merge(local.common_tags, {
    Name    = local.backup_bucket_name
    Purpose = "Database and application backups"
  })
}

resource "aws_s3_bucket_versioning" "backups" {
  count = local.s3_enabled ? 1 : 0

  bucket = aws_s3_bucket.backups[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  count = local.s3_enabled ? 1 : 0

  bucket = aws_s3_bucket.backups[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3[0].arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  count = local.s3_enabled ? 1 : 0

  bucket = aws_s3_bucket.backups[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy for backups
resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  count = local.s3_enabled ? 1 : 0

  bucket = aws_s3_bucket.backups[0].id

  rule {
    id     = "delete_old_versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = local.backup_retention_days
    }
  }

  rule {
    id     = "transition_to_glacier"
    status = local.is_production ? "Enabled" : "Disabled"

    filter {}

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    transition {
      days          = 180 # Must be 90 days after GLACIER (30 + 90 = 120, using 180 for safety)
      storage_class = "DEEP_ARCHIVE"
    }
  }
}
