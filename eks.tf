module "eks" {
  count = local.eks_enabled ? 1 : 0

  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "eks-${var.project_name}"
  kubernetes_version = "1.31"

  endpoint_public_access  = true
  endpoint_private_access = true

  enable_irsa = true

  vpc_id     = aws_vpc.vpc.id
  subnet_ids = aws_subnet.private[*].id

  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    general = {
      name = "general"

      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = local.is_production ? ["t3.medium"] : ["t3.small", "t3.medium"]
      capacity_type  = "SPOT"

      min_size     = 1
      max_size     = 3
      desired_size = local.is_production ? 2 : 1

      disk_size              = 20
      enable_bootstrap_user_data = true

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 20
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      labels = {
        role = "general"
      }

      tags = merge(local.common_tags, {
        Name = "eks-${var.project_name}-general-nodegroup"
      })
    }
  }

  tags = local.common_tags
}