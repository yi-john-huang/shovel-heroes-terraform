# EKS Add-ons - Essential cluster components

# VPC CNI - Provides networking for pods
resource "aws_eks_addon" "vpc_cni" {
  count = local.eks_enabled ? 1 : 0

  cluster_name = module.eks[0].cluster_name
  addon_name   = "vpc-cni"

  addon_version            = data.aws_eks_addon_version.vpc_cni[0].version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = local.common_tags
}

# CoreDNS - Provides DNS for the cluster
resource "aws_eks_addon" "coredns" {
  count = local.eks_enabled ? 1 : 0

  cluster_name = module.eks[0].cluster_name
  addon_name   = "coredns"

  addon_version            = data.aws_eks_addon_version.coredns[0].version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = local.common_tags

  depends_on = [
    aws_eks_addon.vpc_cni
  ]
}

# kube-proxy - Maintains network rules on nodes
resource "aws_eks_addon" "kube_proxy" {
  count = local.eks_enabled ? 1 : 0

  cluster_name = module.eks[0].cluster_name
  addon_name   = "kube-proxy"

  addon_version            = data.aws_eks_addon_version.kube_proxy[0].version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = local.common_tags
}

# Data sources to get latest addon versions
data "aws_eks_addon_version" "vpc_cni" {
  count = local.eks_enabled ? 1 : 0

  addon_name         = "vpc-cni"
  kubernetes_version = module.eks[0].cluster_version
  most_recent        = true
}

data "aws_eks_addon_version" "coredns" {
  count = local.eks_enabled ? 1 : 0

  addon_name         = "coredns"
  kubernetes_version = module.eks[0].cluster_version
  most_recent        = true
}

data "aws_eks_addon_version" "kube_proxy" {
  count = local.eks_enabled ? 1 : 0

  addon_name         = "kube-proxy"
  kubernetes_version = module.eks[0].cluster_version
  most_recent        = true
}
