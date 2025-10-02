resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count = local.eks_enabled ? 1 : 0

  alarm_name          = "${var.project_name}-${local.env_type}-high-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EKS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors EKS cluster CPU utilization"

  dimensions = {
    ClusterName = module.eks[0].cluster_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  count = local.rds_enabled ? 1 : 0

  alarm_name          = "${var.project_name}-${local.env_type}-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "75"
  alarm_description   = "This metric monitors RDS CPU utilization"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.default[0].id
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${local.env_type}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = local.eks_enabled ? [
            ["AWS/EKS", "CPUUtilization", "ClusterName", module.eks[0].cluster_name],
            [".", "MemoryUtilization", ".", "."]
          ] : []
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.id
          title   = "EKS Cluster Metrics"
          period  = 300
        }
      }
    ]
  })
}