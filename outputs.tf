output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.vpc.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = aws_vpc.vpc.cidr_block
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = local.eks_enabled ? module.eks[0].cluster_endpoint : null
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = local.eks_enabled ? module.eks[0].cluster_name : null
}

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = local.eks_enabled ? module.eks[0].cluster_security_group_id : null
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = local.rds_enabled ? aws_db_instance.default[0].endpoint : null
  sensitive   = true
}

## ECR Repositories
output "ecr_repository_urls" {
  description = "ECR repository URLs for container images"
  value = {
    for repo_name, repo in aws_ecr_repository.app :
    repo_name => repo.repository_url
  }
}

## Application Load Balancer
output "alb_dns_name" {
  description = "ALB DNS name for API access"
  value       = local.alb_enabled ? aws_lb.api[0].dns_name : null
}

output "alb_zone_id" {
  description = "ALB Route53 zone ID"
  value       = local.alb_enabled ? aws_lb.api[0].zone_id : null
}

output "alb_arn" {
  description = "ALB ARN"
  value       = local.alb_enabled ? aws_lb.api[0].arn : null
}

output "backend_target_group_arn" {
  description = "Backend target group ARN for Kubernetes service"
  value       = local.alb_enabled ? aws_lb_target_group.backend[0].arn : null
}

## Database
output "rds_address" {
  description = "RDS instance address (without port)"
  value       = local.rds_enabled ? aws_db_instance.default[0].address : null
  sensitive   = true
}

output "rds_port" {
  description = "RDS instance port"
  value       = local.rds_enabled ? aws_db_instance.default[0].port : null
}

output "rds_database_name" {
  description = "Database name"
  value       = local.rds_enabled ? aws_db_instance.default[0].db_name : null
}

output "database_url_format" {
  description = "Database URL format (replace PASSWORD)"
  value       = local.rds_enabled ? "postgres://dbadmin:PASSWORD@${aws_db_instance.default[0].endpoint}/${local.db_name}" : null
  sensitive   = true
}

## Secrets Manager
output "database_secret_arn" {
  description = "ARN of database credentials secret"
  value       = local.rds_enabled ? aws_secretsmanager_secret.database[0].arn : null
  sensitive   = true
}

output "jwt_secret_arn" {
  description = "ARN of JWT secret"
  value       = aws_secretsmanager_secret.jwt.arn
  sensitive   = true
}

output "application_secret_arn" {
  description = "ARN of application secrets"
  value       = aws_secretsmanager_secret.application.arn
  sensitive   = true
}

## IAM Roles
output "backend_pod_role_arn" {
  description = "IAM role ARN for backend pods (IRSA)"
  value       = local.eks_enabled ? aws_iam_role.backend_pods[0].arn : null
}

## S3 Buckets
output "frontend_bucket_name" {
  description = "S3 bucket name for frontend static assets"
  value       = local.s3_enabled ? aws_s3_bucket.frontend[0].bucket : null
}

output "frontend_bucket_regional_domain" {
  description = "S3 bucket regional domain name for frontend"
  value       = local.s3_enabled ? aws_s3_bucket.frontend[0].bucket_regional_domain_name : null
}

output "backups_bucket_name" {
  description = "S3 bucket name for backups"
  value       = local.s3_enabled ? aws_s3_bucket.backups[0].bucket : null
}

## Kubernetes Configuration
output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = local.eks_enabled ? "aws eks update-kubeconfig --region ${data.aws_region.current.id} --name ${module.eks[0].cluster_name}" : null
}

## Application URLs
output "api_base_url" {
  description = "Base URL for backend API (HTTP)"
  value       = local.alb_enabled ? "http://${aws_lb.api[0].dns_name}" : null
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = local.s3_enabled && local.is_production ? aws_cloudfront_distribution.frontend[0].id : null
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = local.s3_enabled && local.is_production ? aws_cloudfront_distribution.frontend[0].domain_name : null
}

output "frontend_url" {
  description = "Frontend URL (via CloudFront in prod, S3 website in non-prod)"
  value       = local.s3_enabled ? (local.is_production ? "https://${aws_cloudfront_distribution.frontend[0].domain_name}" : "http://${aws_s3_bucket.frontend[0].bucket}.s3-website.${data.aws_region.current.id}.amazonaws.com") : null
}

## Security Groups
output "backend_pods_security_group_id" {
  description = "Security group ID for backend pods"
  value       = local.eks_enabled ? aws_security_group.backend_pods[0].id : null
}

output "alb_security_group_id" {
  description = "Security group ID for ALB"
  value       = local.alb_enabled ? aws_security_group.alb[0].id : null
}

## Route53 DNS
output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = var.domain_name != "" ? aws_route53_zone.main[0].zone_id : null
}

output "route53_name_servers" {
  description = "Route53 name servers (configure these in your domain registrar)"
  value       = var.domain_name != "" ? aws_route53_zone.main[0].name_servers : null
}

output "domain_name" {
  description = "Configured domain name"
  value       = var.domain_name != "" ? var.domain_name : null
}

output "api_domain" {
  description = "API domain name"
  value       = var.domain_name != "" && local.alb_enabled ? "api.${var.domain_name}" : null
}

## Deployment Information
output "deployment_summary" {
  description = "Summary of deployed resources for Shovel Heroes"
  value = {
    project_name = var.project_name
    environment  = local.env_type
    region       = data.aws_region.current.id
    eks_enabled  = local.eks_enabled
    rds_enabled  = local.rds_enabled
    alb_enabled  = local.alb_enabled
    s3_enabled   = local.s3_enabled
    application  = local.app_name
    backend_port = local.backend_port
    domain_name  = var.domain_name
  }
}