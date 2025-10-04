# Route53 DNS configuration for Shovel Heroes

# Hosted zone for the domain
resource "aws_route53_zone" "main" {
  count = var.domain_name != "" ? 1 : 0

  name = var.domain_name

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.env_type}-hosted-zone"
  })
}

# A record for ALB (root domain - frontend)
resource "aws_route53_record" "root" {
  count = local.alb_enabled && var.domain_name != "" ? 1 : 0

  zone_id = aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.api[0].dns_name
    zone_id                = aws_lb.api[0].zone_id
    evaluate_target_health = true
  }
}

# A record for ALB (API subdomain - backend)
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

# ACM certificate validation
resource "aws_acm_certificate_validation" "api" {
  count = var.domain_name != "" && local.alb_enabled ? 1 : 0

  certificate_arn         = aws_acm_certificate.api[0].arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation_alb : record.fqdn]
}
