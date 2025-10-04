# AWS Secrets Manager for application secrets
# These secrets will be injected into EKS pods as environment variables

# Database credentials secret
resource "aws_secretsmanager_secret" "database" {
  count = local.rds_enabled ? 1 : 0

  name_prefix             = "${var.project_name}-${local.env_type}-db-"
  description             = "Database credentials for ${local.app_name}"
  recovery_window_in_days = local.is_production ? 30 : 7
  kms_key_id              = aws_kms_key.secrets.arn

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.env_type}-database-secret"
  })
}

# Database secret value - stores connection details
resource "aws_secretsmanager_secret_version" "database" {
  count = local.rds_enabled ? 1 : 0

  secret_id = aws_secretsmanager_secret.database[0].id
  secret_string = jsonencode({
    username = aws_db_instance.default[0].username
    password = var.secrets.database_password
    engine   = local.db_engine
    host     = aws_db_instance.default[0].endpoint
    port     = local.db_port
    dbname   = local.db_name
    # Full DATABASE_URL for Node.js pg library
    database_url = "postgres://${aws_db_instance.default[0].username}:${var.secrets.database_password}@${aws_db_instance.default[0].endpoint}/${local.db_name}"
  })
}

# JWT secret for authentication
resource "aws_secretsmanager_secret" "jwt" {
  name_prefix             = "${var.project_name}-${local.env_type}-jwt-"
  description             = "JWT secret for ${local.app_name} authentication"
  recovery_window_in_days = local.is_production ? 30 : 7
  kms_key_id              = aws_kms_key.secrets.arn

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.env_type}-jwt-secret"
  })
}

# Generate random JWT secret
resource "random_password" "jwt_secret" {
  length  = 64
  special = true
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id = aws_secretsmanager_secret.jwt.id
  secret_string = jsonencode({
    secret = random_password.jwt_secret.result
  })
}

# Application secrets - for API keys, tokens, etc.
resource "aws_secretsmanager_secret" "application" {
  name_prefix             = "${var.project_name}-${local.env_type}-app-"
  description             = "Application secrets for ${local.app_name}"
  recovery_window_in_days = local.is_production ? 30 : 7
  kms_key_id              = aws_kms_key.secrets.arn

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.env_type}-app-secret"
  })
}

resource "aws_secretsmanager_secret_version" "application" {
  secret_id = aws_secretsmanager_secret.application.id
  secret_string = jsonencode({
    node_env              = local.env_type == "prod" ? "production" : "development"
    port                  = local.backend_port
    line_channel_id       = var.secrets.line_channel_id
    line_channel_secret   = var.secrets.line_channel_secret
    turnstile_secret_key  = var.secrets.turnstile_secret_key
  })
}

# IAM policy for pods to read secrets
resource "aws_iam_policy" "secrets_read" {
  name_prefix = "${var.project_name}-${local.env_type}-secrets-read-"
  description = "Allow reading secrets for ${local.app_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = compact([
          local.rds_enabled ? aws_secretsmanager_secret.database[0].arn : "",
          aws_secretsmanager_secret.jwt.arn,
          aws_secretsmanager_secret.application.arn
        ])
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = [aws_kms_key.secrets.arn]
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.id}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}
