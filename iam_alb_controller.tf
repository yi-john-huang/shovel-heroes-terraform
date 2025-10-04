# IAM Role and Policy for AWS Load Balancer Controller

# Download ALB controller IAM policy
data "http" "alb_controller_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.13.4/docs/install/iam_policy.json"
}

# IAM policy for ALB controller
resource "aws_iam_policy" "alb_controller" {
  count = local.eks_enabled ? 1 : 0

  name_prefix = "${var.project_name}-${local.env_type}-alb-controller-"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = data.http.alb_controller_iam_policy.response_body

  tags = local.common_tags
}

# IAM role for ALB controller (IRSA)
resource "aws_iam_role" "alb_controller" {
  count = local.eks_enabled ? 1 : 0

  name_prefix = "${var.project_name}-${local.env_type}-alb-controller-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks[0].oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(module.eks[0].oidc_provider, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${replace(module.eks[0].oidc_provider, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = local.common_tags
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "alb_controller" {
  count = local.eks_enabled ? 1 : 0

  role       = aws_iam_role.alb_controller[0].name
  policy_arn = aws_iam_policy.alb_controller[0].arn
}

# Kubernetes service account for ALB controller
resource "kubernetes_service_account" "alb_controller" {
  count = local.eks_enabled ? 1 : 0

  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller[0].arn
    }
    labels = {
      "app.kubernetes.io/component" = "controller"
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
    }
  }
}

# Output
output "alb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = local.eks_enabled ? aws_iam_role.alb_controller[0].arn : null
}
