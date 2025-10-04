# Bastion with SSM Session Manager (no SSH key needed)
resource "aws_instance" "bastion_ssm" {
  count = local.rds_enabled ? 1 : 0

  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.private[0].id # Private subnet!

  vpc_security_group_ids = [aws_security_group.bastion_ssm[0].id]
  iam_instance_profile   = aws_iam_instance_profile.bastion_ssm[0].name

  user_data = <<-USERDATA
    #!/bin/bash
    yum update -y
    yum install -y postgresql15
  USERDATA

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.env_type}-bastion-ssm"
  })
}

resource "aws_security_group" "bastion_ssm" {
  count = local.rds_enabled ? 1 : 0

  name_prefix = "${var.project_name}-${local.env_type}-bastion-ssm-"
  vpc_id      = aws_vpc.vpc.id

  # No inbound rules needed - SSM uses outbound only

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.env_type}-bastion-ssm-sg"
  })
}

# IAM role for SSM
resource "aws_iam_role" "bastion_ssm" {
  count = local.rds_enabled ? 1 : 0

  name_prefix = "${var.project_name}-${local.env_type}-bastion-ssm-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  count = local.rds_enabled ? 1 : 0

  role       = aws_iam_role.bastion_ssm[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion_ssm" {
  count = local.rds_enabled ? 1 : 0

  name_prefix = "${var.project_name}-${local.env_type}-bastion-ssm-"
  role        = aws_iam_role.bastion_ssm[0].name
}

# Allow bastion to access RDS
resource "aws_security_group_rule" "rds_from_bastion_ssm" {
  count = local.rds_enabled ? 1 : 0

  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg[0].id
  source_security_group_id = aws_security_group.bastion_ssm[0].id
}

output "bastion_ssm_instance_id" {
  description = "Bastion instance ID for SSM Session Manager"
  value       = local.rds_enabled ? aws_instance.bastion_ssm[0].id : null
}
