# S3 website configuration for non-production (cost-saving alternative to CloudFront)
# In production, CloudFront is used instead for better security and performance

resource "aws_s3_bucket_website_configuration" "frontend" {
  count = local.s3_enabled && !local.is_production ? 1 : 0

  bucket = aws_s3_bucket.frontend[0].id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html" # SPA routing
  }
}
