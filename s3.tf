# S3 buckets for Shovel Heroes application

# Random suffix for unique bucket names
resource "random_string" "bucket_suffix" {
  count = local.s3_enabled ? 1 : 0

  length  = 8
  special = false
  upper   = false
}

## Frontend Static Assets Bucket

resource "aws_s3_bucket" "frontend" {
  count = local.s3_enabled ? 1 : 0

  bucket = "${local.frontend_bucket_name}-${random_string.bucket_suffix[0].result}"

  tags = merge(local.common_tags, {
    Name    = local.frontend_bucket_name
    Purpose = "Frontend static assets (React build)"
  })
}

resource "aws_s3_bucket_versioning" "frontend" {
  count = local.s3_enabled ? 1 : 0

  bucket = aws_s3_bucket.frontend[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  count = local.s3_enabled ? 1 : 0

  bucket = aws_s3_bucket.frontend[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Public access for frontend bucket (will be served by CloudFront)
resource "aws_s3_bucket_public_access_block" "frontend" {
  count = local.s3_enabled ? 1 : 0

  bucket = aws_s3_bucket.frontend[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = local.cloudfront_enabled # Allow public if no CloudFront
}

# Website configuration for S3 static hosting (fallback if no CloudFront)
resource "aws_s3_bucket_website_configuration" "frontend" {
  count = local.s3_enabled && !local.cloudfront_enabled ? 1 : 0

  bucket = aws_s3_bucket.frontend[0].id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html" # SPA routing
  }
}

# Bucket policy for CloudFront access
resource "aws_s3_bucket_policy" "frontend" {
  count = local.s3_enabled && local.cloudfront_enabled ? 1 : 0

  bucket = aws_s3_bucket.frontend[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontAccess"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend[0].arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend[0].arn
          }
        }
      }
    ]
  })
}

## Logs Bucket

resource "aws_s3_bucket" "logs" {
  count = local.s3_enabled ? 1 : 0

  bucket = "${local.logs_bucket_name}-${random_string.bucket_suffix[0].result}"

  tags = merge(local.common_tags, {
    Name    = local.logs_bucket_name
    Purpose = "Application and infrastructure logs"
  })
}

resource "aws_s3_bucket_versioning" "logs" {
  count = local.s3_enabled ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id
  versioning_configuration {
    status = "Disabled" # Logs don't need versioning
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  count = local.s3_enabled ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  count = local.s3_enabled ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy for logs - delete after retention period
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  count = local.s3_enabled ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  rule {
    id     = "delete_old_logs"
    status = "Enabled"

    expiration {
      days = local.log_retention_days
    }
  }

  rule {
    id     = "transition_to_glacier"
    status = local.is_production ? "Enabled" : "Disabled"

    transition {
      days          = 7
      storage_class = "GLACIER"
    }
  }
}

## Backups Bucket

resource "aws_s3_bucket" "backups" {
  count = local.s3_enabled ? 1 : 0

  bucket = "${local.backup_bucket_name}-${random_string.bucket_suffix[0].result}"

  tags = merge(local.common_tags, {
    Name    = local.backup_bucket_name
    Purpose = "Database backups and application data backups"
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
      sse_algorithm = "AES256"
    }
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

    noncurrent_version_expiration {
      noncurrent_days = local.backup_retention_days
    }
  }

  rule {
    id     = "transition_to_glacier"
    status = local.is_production ? "Enabled" : "Disabled"

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    transition {
      days          = 90
      storage_class = "DEEP_ARCHIVE"
    }
  }
}
