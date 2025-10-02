resource "aws_security_group" "external_sg" {
  name_prefix = "${var.project_name}-${local.env_type}-external-"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.env_type}-external-sg"
  })
}

resource "aws_security_group" "internal_sg" {
  name_prefix = "${var.project_name}-${local.env_type}-internal-"
  vpc_id      = aws_vpc.vpc.id

  # Backend API traffic
  ingress {
    description = "Backend API from VPC"
    from_port   = local.backend_port
    to_port     = local.backend_port
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  # PostgreSQL database traffic
  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  # HTTPS for outbound API calls
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.env_type}-internal-sg"
  })
}

resource "aws_security_group" "rds_sg" {
  count = local.rds_enabled ? 1 : 0

  name_prefix = "${var.project_name}-${local.env_type}-rds-"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description     = "MySQL/Aurora"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.internal_sg.id]
  }

  ingress {
    description     = "PostgreSQL from internal"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.internal_sg.id]
  }

  ingress {
    description     = "PostgreSQL from backend pods"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = local.eks_enabled ? [aws_security_group.backend_pods[0].id] : []
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.env_type}-rds-sg"
  })
}

# ALB security group
resource "aws_security_group" "alb" {
  count = local.alb_enabled ? 1 : 0

  name_prefix = "${var.project_name}-${local.env_type}-alb-"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.env_type}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Backend pods security group
resource "aws_security_group" "backend_pods" {
  count = local.eks_enabled ? 1 : 0

  name_prefix = "${var.project_name}-${local.env_type}-backend-pods-"
  vpc_id      = aws_vpc.vpc.id

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.env_type}-backend-pods-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security group rules for backend pods (separate to avoid duplicates)
resource "aws_security_group_rule" "backend_pods_from_alb" {
  count = local.eks_enabled && local.alb_enabled ? 1 : 0

  type                     = "ingress"
  from_port                = local.backend_port
  to_port                  = local.backend_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb[0].id
  security_group_id        = aws_security_group.backend_pods[0].id
  description              = "Backend API port from ALB"
}

resource "aws_security_group_rule" "backend_pods_from_vpc" {
  count = local.eks_enabled ? 1 : 0

  type              = "ingress"
  from_port         = local.backend_port
  to_port           = local.backend_port
  protocol          = "tcp"
  cidr_blocks       = [local.vpc_cidr]
  security_group_id = aws_security_group.backend_pods[0].id
  description       = "Backend API port and health checks from VPC"
}