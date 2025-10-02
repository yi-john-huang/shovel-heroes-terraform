# CloudFront distribution for frontend S3 bucket
# Provides CDN caching, DDoS protection, and private S3 access via OAC
# Note: CloudFront costs ~$1-5/month for low traffic, but adds security and performance

# Origin Access Control for S3 (replaces legacy OAI)
resource "aws_cloudfront_origin_access_control" "frontend" {
  count = local.s3_enabled && local.is_production ? 1 : 0 # Disable for non-prod to save costs

  name                              = "${var.project_name}-${local.env_type}-frontend-oac"
  description                       = "OAC for ${local.app_name} frontend bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "frontend" {
  count = local.s3_enabled && local.is_production ? 1 : 0 # Disable for non-prod to save costs

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${local.app_name} frontend distribution"
  default_root_object = "index.html"
  price_class         = local.is_production ? "PriceClass_All" : "PriceClass_100"
  aliases             = var.domain_name != "" ? [var.domain_name, "www.${var.domain_name}"] : []

  origin {
    domain_name              = aws_s3_bucket.frontend[0].bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.frontend[0].id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend[0].id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.frontend[0].id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600  # 1 hour
    max_ttl                = 86400 # 24 hours
    compress               = true

    # Security headers via response headers policy
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers[0].id
  }

  # Custom error responses for SPA routing
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.domain_name == ""
    acm_certificate_arn            = var.domain_name != "" ? aws_acm_certificate.frontend[0].arn : null
    ssl_support_method             = var.domain_name != "" ? "sni-only" : null
    minimum_protocol_version       = var.domain_name != "" ? "TLSv1.2_2021" : null
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.env_type}-frontend-cdn"
  })
}

# Security headers policy
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  count = local.s3_enabled && local.is_production ? 1 : 0

  name    = "${var.project_name}-${local.env_type}-security-headers"
  comment = "Security headers for ${local.app_name}"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000 # 1 year
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    content_security_policy {
      content_security_policy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' ${local.alb_enabled ? "https://${aws_lb.api[0].dns_name}" : ""}; frame-ancestors 'none';"
      override                = true
    }
  }
}

# ACM certificate for CloudFront (must be in us-east-1)
resource "aws_acm_certificate" "frontend" {
  count = local.s3_enabled && local.is_production && var.domain_name != "" ? 1 : 0

  provider          = aws.us_east_1
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "www.${var.domain_name}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.env_type}-frontend-certificate"
  })
}

# Note: DNS validation records need to be created in your DNS provider
# Same process as the ALB certificate in acm.tf
