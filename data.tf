data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_eks_cluster" "cluster" {
  count = local.eks_enabled ? 1 : 0
  name  = module.eks[0].cluster_name

  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "cluster" {
  count = local.eks_enabled ? 1 : 0
  name  = module.eks[0].cluster_name

  depends_on = [module.eks]
}