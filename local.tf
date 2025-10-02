locals {
  # Environment settings
  env_type      = var.env_vars.env_type
  env_name      = var.env_vars.env_name
  is_production = local.env_type == "prod"

  # Application settings
  app_name      = "shovel-heroes"
  backend_port  = 8787
  frontend_port = 3000

  # Feature flags - Control which components to deploy
  eks_enabled        = true
  rds_enabled        = true
  s3_enabled         = true
  alb_enabled        = true
  cloudfront_enabled = true
  taipei_enabled     = false # Multi-region deployment to Taipei

  # Networking
  vpc_cidr = "10.0.0.0/16"
  availability_zones = slice(
    data.aws_availability_zones.available.names,
    0,
    3 # Use 3 AZs for high availability
  )

  # EKS Configuration
  eks_cluster_name = "${var.project_name}-${local.env_type}-eks"
  eks_version      = "1.31"

  # Node.js / Application Configuration
  node_version = "20" # Node.js version for application

  # Database Configuration
  db_name           = "shovelheroes"
  db_port           = 5432
  db_engine         = "postgres"
  db_engine_version = "16.8"

  # ECR Configuration
  ecr_repositories = [
    "${local.app_name}-backend",
    "${local.app_name}-frontend" # Optional if using S3 for frontend
  ]

  # S3 Bucket names
  frontend_bucket_name = "${var.project_name}-${local.env_type}-frontend"
  logs_bucket_name     = "${var.project_name}-${local.env_type}-logs"
  backup_bucket_name   = "${var.project_name}-${local.env_type}-backups"

  # CloudFront
  cloudfront_price_class = local.is_production ? "PriceClass_200" : "PriceClass_100"

  # Common tags applied to all resources
  common_tags = {
    Project     = var.project_name
    Application = local.app_name
    Environment = local.env_type
    ManagedBy   = "terraform"
    CreatedBy   = data.aws_caller_identity.current.arn
    Region      = data.aws_region.current.name
  }

  # ALB Configuration
  alb_name = "${var.project_name}-${local.env_type}-alb"

  # Health check configuration
  health_check_path     = "/healthz"
  health_check_interval = 30
  health_check_timeout  = 5
  healthy_threshold     = 2
  unhealthy_threshold   = 3

  # Auto-scaling configuration
  backend_min_replicas     = local.is_production ? 2 : 1
  backend_max_replicas     = local.is_production ? 10 : 3
  backend_desired_replicas = local.is_production ? 3 : 1

  # Log retention
  log_retention_days = local.is_production ? 30 : 7

  # Backup retention
  backup_retention_days = local.is_production ? 7 : 1

  # Resource sizing based on environment
  eks_node_instance_types   = local.is_production ? ["t3.large", "t3.xlarge"] : ["t3.medium"]
  rds_instance_class        = local.is_production ? "db.t3.small" : "db.t3.micro"
  rds_allocated_storage     = local.is_production ? 100 : 20
  rds_max_allocated_storage = local.is_production ? 500 : 100
}
