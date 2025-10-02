resource "aws_db_subnet_group" "default" {
  count = local.rds_enabled ? 1 : 0

  name       = "${var.project_name}-${local.env_type}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.env_type}-db-subnet-group"
  })
}

resource "aws_db_parameter_group" "default" {
  count = local.rds_enabled ? 1 : 0

  family = "postgres16"
  name   = "${var.project_name}-${local.env_type}-db-params"

  # Logging parameters
  parameter {
    name  = "log_statement"
    value = local.is_production ? "ddl" : "all" # Less verbose in production
  }

  parameter {
    name  = "log_min_duration_statement"
    value = local.is_production ? "1000" : "500" # Log slow queries (ms)
  }

  # Connection pooling optimizations for Node.js/pg
  parameter {
    name  = "max_connections"
    value = local.is_production ? "200" : "100"
  }

  parameter {
    name  = "shared_buffers"
    value = local.is_production ? "{DBInstanceClassMemory/10240}" : "{DBInstanceClassMemory/16384}"
  }

  # Performance optimizations
  parameter {
    name  = "effective_cache_size"
    value = local.is_production ? "{DBInstanceClassMemory/2}" : "{DBInstanceClassMemory/4}"
  }

  parameter {
    name  = "work_mem"
    value = local.is_production ? "16384" : "8192" # 16MB or 8MB
  }

  tags = local.common_tags
}

resource "aws_db_instance" "default" {
  count = local.rds_enabled ? 1 : 0

  identifier = "${var.project_name}-${local.env_type}-db"

  allocated_storage     = local.rds_allocated_storage
  max_allocated_storage = local.rds_max_allocated_storage
  storage_type          = "gp3" # gp3 is more cost-effective than gp2
  storage_encrypted     = true
  iops                  = local.is_production ? 3000 : null # For gp3, optional IOPS

  engine         = local.db_engine
  engine_version = local.db_engine_version
  instance_class = local.rds_instance_class

  db_name  = local.db_name # "shovelheroes"
  username = "dbadmin"
  password = var.secrets.database_password
  port     = local.db_port

  vpc_security_group_ids = [aws_security_group.rds_sg[0].id]
  db_subnet_group_name   = aws_db_subnet_group.default[0].name
  parameter_group_name   = aws_db_parameter_group.default[0].name

  backup_retention_period = local.backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  skip_final_snapshot       = !local.is_production
  final_snapshot_identifier = local.is_production ? "${var.project_name}-${local.env_type}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  # Performance Insights
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]
  performance_insights_enabled          = local.is_production
  performance_insights_retention_period = local.is_production ? 7 : null

  # Enhanced Monitoring
  monitoring_interval = local.is_production ? 60 : 0 # 0 disables enhanced monitoring
  monitoring_role_arn = local.is_production ? aws_iam_role.rds_enhanced_monitoring[0].arn : null

  # Multi-AZ for production
  multi_az = local.is_production

  # Auto minor version upgrade
  auto_minor_version_upgrade = true

  # Deletion protection for production
  deletion_protection = local.is_production

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.env_type}-database"
  })
}

# IAM role for RDS enhanced monitoring
resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = local.rds_enabled && local.is_production ? 1 : 0

  name_prefix = "${var.project_name}-${local.env_type}-rds-monitoring-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count = local.rds_enabled && local.is_production ? 1 : 0

  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}