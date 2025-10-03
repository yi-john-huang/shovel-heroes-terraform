# Route53 DNS configuration for Shovel Heroes

# Hosted zone for the domain
resource "aws_route53_zone" "main" {
  count = var.domain_name != "" ? 1 : 0

  name = var.domain_name

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.env_type}-hosted-zone"
  })
}

# A record for ALB (API and backend)
resource "aws_route53_record" "api" {
  count = local.alb_enabled && var.domain_name != "" ? 1 : 0

  zone_id = aws_route53_zone.main[0].zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.api[0].dns_name
    zone_id                = aws_lb.api[0].zone_id
    evaluate_target_health = true
  }
}

# A record for root domain pointing to CloudFront (production) or S3 (non-prod)
resource "aws_route53_record" "root" {
  count = var.domain_name != "" && local.s3_enabled ? 1 : 0

  zone_id = aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  dynamic "alias" {
    for_each = local.is_production ? [1] : []
    content {
      name                   = aws_cloudfront_distribution.frontend[0].domain_name
      zone_id                = aws_cloudfront_distribution.frontend[0].hosted_zone_id
      evaluate_target_health = false
    }
  }

  dynamic "alias" {
    for_each = local.is_production ? [] : [1]
    content {
      name                   = aws_s3_bucket_website_configuration.frontend[0].website_domain
      zone_id                = aws_s3_bucket.frontend[0].hosted_zone_id
      evaluate_target_health = false
    }
  }
}

# A record for www subdomain
resource "aws_route53_record" "www" {
  count = var.domain_name != "" && local.s3_enabled ? 1 : 0

  zone_id = aws_route53_zone.main[0].zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  dynamic "alias" {
    for_each = local.is_production ? [1] : []
    content {
      name                   = aws_cloudfront_distribution.frontend[0].domain_name
      zone_id                = aws_cloudfront_distribution.frontend[0].hosted_zone_id
      evaluate_target_health = false
    }
  }

  dynamic "alias" {
    for_each = local.is_production ? [] : [1]
    content {
      name                   = aws_s3_bucket_website_configuration.frontend[0].website_domain
      zone_id                = aws_s3_bucket.frontend[0].hosted_zone_id
      evaluate_target_health = false
    }
  }
}

# ACM certificate validation records
resource "aws_route53_record" "acm_validation_alb" {
  for_each = {
    for dvo in var.domain_name != "" && local.alb_enabled ? aws_acm_certificate.api[0].domain_validation_options : [] : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main[0].zone_id
}

# ACM certificate validation records for CloudFront (us-east-1)
resource "aws_route53_record" "acm_validation_cloudfront" {
  for_each = {
    for dvo in var.domain_name != "" && local.s3_enabled && local.is_production ? aws_acm_certificate.frontend[0].domain_validation_options : [] : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main[0].zone_id
}

# ACM certificate validation
resource "aws_acm_certificate_validation" "api" {
  count = var.domain_name != "" && local.alb_enabled ? 1 : 0

  certificate_arn         = aws_acm_certificate.api[0].arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation_alb : record.fqdn]
}

# ACM certificate validation for CloudFront
resource "aws_acm_certificate_validation" "frontend" {
  count = var.domain_name != "" && local.s3_enabled && local.is_production ? 1 : 0

  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.frontend[0].arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation_cloudfront : record.fqdn]
}
