module "eks" {
  count = local.eks_enabled ? 1 : 0

  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  cluster_name    = local.eks_cluster_name
  cluster_version = "1.31"

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  enable_irsa = true

  vpc_id     = aws_vpc.vpc.id
  subnet_ids = aws_subnet.private[*].id

  # Authentication mode - use API_AND_CONFIG_MAP for compatibility
  authentication_mode = "API_AND_CONFIG_MAP"

  # Access entries for cluster access (replaces aws-auth ConfigMap)
  enable_cluster_creator_admin_permissions = true

  access_entries = {
    eks_admin = {
      principal_arn     = aws_iam_role.eks_admin[0].arn
      kubernetes_groups = ["system:masters"]
    }
  }

  eks_managed_node_groups = {
    general = {
      name = "general"

      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"

      min_size     = 1
      max_size     = 3
      desired_size = 2

      labels = {
        role = "general"
      }

      tags = merge(local.common_tags, {
        Name = "${local.eks_cluster_name}-general-nodegroup"
      })
    }

    workflow = {
      name = "workflow"

      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"

      min_size     = 0
      max_size     = 5
      desired_size = 1

      taints = [
        {
          key    = "workflow"
          value  = "true"
          effect = "NoSchedule"
        }
      ]

      labels = {
        role = "workflow"
      }

      tags = merge(local.common_tags, {
        Name = "${local.eks_cluster_name}-workflow-nodegroup"
      })
    }

    compute = {
      name = "compute"

      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["c5.xlarge"]
      capacity_type  = "ON_DEMAND"

      min_size     = 0
      max_size     = 10
      desired_size = 0

      taints = [
        {
          key    = "compute"
          value  = "true"
          effect = "NoSchedule"
        }
      ]

      labels = {
        role = "compute"
      }

      tags = merge(local.common_tags, {
        Name = "${local.eks_cluster_name}-compute-nodegroup"
      })
    }
  }

  tags = local.common_tags
}