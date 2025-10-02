# ACM Certificate for HTTPS on ALB
# Note: You will need to own a domain and validate the certificate

# Primary certificate for the application
resource "aws_acm_certificate" "api" {
  count = local.alb_enabled && var.domain_name != "" ? 1 : 0

  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.domain_name}" # Wildcard for subdomains
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.env_type}-certificate"
  })
}

# Note: DNS validation records need to be created in your DNS provider
# You can either:
# 1. Manually create the validation records shown in the AWS Console
# 2. Use Route53 resources if your domain is in Route53 (uncomment below)

# # If using Route53 for DNS management
# data "aws_route53_zone" "primary" {
#   count = local.alb_enabled ? 1 : 0
#
#   name         = var.domain_name
#   private_zone = false
# }
#
# resource "aws_route53_record" "cert_validation" {
#   for_each = local.alb_enabled ? {
#     for dvo in aws_acm_certificate.api[0].domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       record = dvo.resource_record_value
#       type   = dvo.resource_record_type
#     }
#   } : {}
#
#   allow_overwrite = true
#   name            = each.value.name
#   records         = [each.value.record]
#   ttl             = 60
#   type            = each.value.type
#   zone_id         = data.aws_route53_zone.primary[0].zone_id
# }
#
# resource "aws_acm_certificate_validation" "api" {
#   count = local.alb_enabled ? 1 : 0
#
#   certificate_arn         = aws_acm_certificate.api[0].arn
#   validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
# }
