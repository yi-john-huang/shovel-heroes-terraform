# Application Load Balancer for backend API

# ALB for the backend API
resource "aws_lb" "api" {
  count = local.alb_enabled ? 1 : 0

  name               = local.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection       = local.is_production
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  access_logs {
    bucket  = aws_s3_bucket.logs[0].id
    prefix  = "alb"
    enabled = true
  }

  tags = merge(local.common_tags, {
    Name = local.alb_name
  })
}

# Target group for backend pods
resource "aws_lb_target_group" "backend" {
  count = local.alb_enabled ? 1 : 0

  name_prefix = "be-"
  port        = local.backend_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "ip" # For EKS pods

  health_check {
    enabled             = true
    path                = local.health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = local.healthy_threshold
    unhealthy_threshold = local.unhealthy_threshold
    timeout             = local.health_check_timeout
    interval            = local.health_check_interval
    matcher             = "200-299"
  }

  deregistration_delay = 30

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400 # 1 day
    enabled         = false
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.env_type}-backend-tg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# HTTP listener (redirect to HTTPS in production)
resource "aws_lb_listener" "http" {
  count = local.alb_enabled ? 1 : 0

  load_balancer_arn = aws_lb.api[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = local.is_production ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = local.is_production ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    target_group_arn = local.is_production ? null : aws_lb_target_group.backend[0].arn
  }

  tags = local.common_tags
}

# HTTPS listener (requires ACM certificate)
# Uncomment when ACM certificate is available
# resource "aws_lb_listener" "https" {
#   count = local.alb_enabled && local.is_production ? 1 : 0
#
#   load_balancer_arn = aws_lb.api[0].arn
#   port              = "443"
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
#   certificate_arn   = aws_acm_certificate.api[0].arn
#
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.backend[0].arn
#   }
#
#   tags = local.common_tags
# }

# Listener rule for API paths
resource "aws_lb_listener_rule" "api" {
  count = local.alb_enabled ? 1 : 0

  listener_arn = aws_lb_listener.http[0].arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend[0].arn
  }

  condition {
    path_pattern {
      values = [
        "/api/*",
        "/healthz",
        "/docs",
        "/docs/*"
      ]
    }
  }

  tags = local.common_tags
}

# CloudWatch alarms for ALB
resource "aws_cloudwatch_metric_alarm" "alb_healthy_hosts" {
  count = local.alb_enabled ? 1 : 0

  alarm_name          = "${var.project_name}-${local.env_type}-alb-healthy-hosts-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = local.backend_min_replicas
  alarm_description   = "Alert when healthy host count is below minimum"
  treat_missing_data  = "breaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.backend[0].arn_suffix
    LoadBalancer = aws_lb.api[0].arn_suffix
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  count = local.alb_enabled ? 1 : 0

  alarm_name          = "${var.project_name}-${local.env_type}-alb-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "5" # 5 seconds
  alarm_description   = "Alert when average response time is high"

  dimensions = {
    LoadBalancer = aws_lb.api[0].arn_suffix
  }

  tags = local.common_tags
}
