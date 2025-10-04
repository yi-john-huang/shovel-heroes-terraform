# AWS Load Balancer Controller Setup

This document describes the AWS Load Balancer Controller setup for the Shovel Heroes EKS cluster.

## Overview

The AWS Load Balancer Controller is a Kubernetes controller that manages AWS Elastic Load Balancers (ALB/NLB) for Kubernetes services. It uses **IRSA (IAM Roles for Service Accounts)** to securely authenticate to AWS APIs without storing credentials.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     EKS Cluster                              │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Namespace: kube-system                              │   │
│  │                                                       │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │  Service Account:                              │  │   │
│  │  │  aws-load-balancer-controller                  │  │   │
│  │  │                                                 │  │   │
│  │  │  Annotations:                                   │  │   │
│  │  │    eks.amazonaws.com/role-arn: <IAM_ROLE_ARN>  │  │   │
│  │  └──────────────┬─────────────────────────────────┘  │   │
│  │                 │                                     │   │
│  │                 │ Assumes Role via OIDC               │   │
│  │                 ▼                                     │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │  Deployment:                                   │  │   │
│  │  │  aws-load-balancer-controller (2 replicas)     │  │   │
│  │  │                                                 │  │   │
│  │  │  Uses Service Account to get AWS credentials   │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Namespace: shovel-heroes                            │   │
│  │                                                       │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │  TargetGroupBinding: backend-tgb               │  │   │
│  │  │    Service: backend                             │  │   │
│  │  │    Port: 8787                                   │  │   │
│  │  │    TargetGroupARN: arn:aws:...                  │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  │                                                       │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │  TargetGroupBinding: frontend-tgb              │  │   │
│  │  │    Service: frontend                            │  │   │
│  │  │    Port: 80                                     │  │   │
│  │  │    TargetGroupARN: arn:aws:...                  │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────┬───────────────────────────────────────────┘
                   │
                   │ OIDC Web Identity Token
                   ▼
┌─────────────────────────────────────────────────────────────┐
│                         AWS IAM                              │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  OIDC Provider:                                      │   │
│  │  oidc.eks.ap-east-2.amazonaws.com/id/27826BF...     │   │
│  └────────────────────┬─────────────────────────────────┘   │
│                       │                                      │
│                       │ Trust Relationship                   │
│                       ▼                                      │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  IAM Role: shovel-heros-staging-alb-controller-...   │   │
│  │                                                       │   │
│  │  Trust Policy:                                        │   │
│  │    - Federated: OIDC Provider ARN                    │   │
│  │    - Action: sts:AssumeRoleWithWebIdentity           │   │
│  │    - Condition:                                       │   │
│  │        StringEquals:                                  │   │
│  │          :sub = system:serviceaccount:kube-system:   │   │
│  │                 aws-load-balancer-controller          │   │
│  │          :aud = sts.amazonaws.com                    │   │
│  │                                                       │   │
│  │  Attached Policies:                                   │   │
│  │    - shovel-heros-staging-alb-controller-policy      │   │
│  └────────────────────┬─────────────────────────────────┘   │
│                       │                                      │
│                       │ Grants Permissions                   │
│                       ▼                                      │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  IAM Policy: ALB Controller Permissions              │   │
│  │                                                       │   │
│  │  Permissions:                                         │   │
│  │    - elasticloadbalancing:*                          │   │
│  │    - ec2:Describe*                                    │   │
│  │    - ec2:AuthorizeSecurityGroup*                     │   │
│  │    - ec2:CreateSecurityGroup                         │   │
│  │    - acm:DescribeCertificate                         │   │
│  │    - wafv2:*WebACL*                                   │   │
│  │    - ... (full policy from AWS docs)                 │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                   │
                   │ API Calls
                   ▼
┌─────────────────────────────────────────────────────────────┐
│                   AWS Services                               │
│                                                              │
│  - Elastic Load Balancing (ALB/NLB)                         │
│  - EC2 (Security Groups, Subnets, VPCs)                     │
│  - ACM (Certificates)                                        │
│  - WAFv2 (Web ACLs)                                          │
└─────────────────────────────────────────────────────────────┘
```

## Terraform Resources

The following Terraform resources are created in `iam_alb_controller.tf`:

### 1. IAM Policy
- **Resource**: `aws_iam_policy.alb_controller`
- **Purpose**: Grants permissions for ALB controller operations
- **Policy Source**: Official AWS Load Balancer Controller IAM policy (v2.13.4)
- **Permissions Include**:
  - `elasticloadbalancing:*` - Manage load balancers, listeners, rules, target groups
  - `ec2:Describe*` - Discover VPC, subnets, instances, security groups
  - `ec2:CreateSecurityGroup`, `ec2:AuthorizeSecurityGroupIngress` - Manage ALB security groups
  - `acm:DescribeCertificate` - Use ACM certificates for HTTPS
  - `wafv2:*WebACL*` - Attach WAF web ACLs to ALBs

### 2. IAM Role with IRSA
- **Resource**: `aws_iam_role.alb_controller`
- **Purpose**: Allows the controller pods to assume an IAM role
- **Trust Relationship**:
  ```json
  {
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/oidc.eks.ap-east-2.amazonaws.com/id/..."
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.ap-east-2.amazonaws.com/id/...:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller",
          "oidc.eks.ap-east-2.amazonaws.com/id/...:aud": "sts.amazonaws.com"
        }
      }
    }]
  }
  ```

### 3. Kubernetes Service Account
- **Resource**: `kubernetes_service_account.alb_controller`
- **Namespace**: `kube-system`
- **Name**: `aws-load-balancer-controller`
- **Annotations**:
  ```yaml
  eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/shovel-heros-staging-alb-controller-...
  ```

## Deployment Process

### 1. Terraform Creates IRSA Resources

```bash
terraform init
terraform apply
```

This creates:
- IAM policy with ALB controller permissions
- IAM role with OIDC trust relationship
- Kubernetes service account with role annotation

### 2. Install Helm Chart

```bash
# Add EKS Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=eks-shovel-heros \
  --set region=ap-east-2 \
  --set vpcId=vpc-0f3e41cf269d3a2f1 \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

**Important**: Set `serviceAccount.create=false` to use the Terraform-created service account.

### 3. Apply TargetGroupBindings

Create TargetGroupBinding CRDs to connect Kubernetes services to ALB target groups:

```yaml
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: backend-tgb
  namespace: shovel-heroes
spec:
  serviceRef:
    name: backend
    port: 8787
  targetGroupARN: arn:aws:elasticloadbalancing:...
  targetType: ip
```

Apply:
```bash
kubectl apply -f backend-targetgroupbinding.yaml
kubectl apply -f frontend-targetgroupbinding.yaml
```

## Verification

### Check Controller Status

```bash
# Verify pods are running
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

### Check TargetGroupBindings

```bash
# List TargetGroupBindings
kubectl get targetgroupbindings -n shovel-heroes

# Describe a binding
kubectl describe targetgroupbinding backend-tgb -n shovel-heroes
```

### Check Target Group Health

```bash
# Backend target group
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw backend_target_group_arn) \
  --region ap-east-2

# Frontend target group
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw frontend_target_group_arn) \
  --region ap-east-2
```

Expected output:
```
TargetHealthDescriptions:
- Target:
    Id: 10.0.11.22  # Backend pod IP
    Port: 8787
  TargetHealth:
    State: healthy
```

**Current Status** (Verified Healthy):
- ✅ Backend target: `10.0.11.22:8787` - healthy
- ✅ Frontend target: `10.0.11.125:8080` - healthy
- ✅ Services: ClusterIP with TargetGroupBinding (targetType: ip)
- ✅ Security: ALB → EKS node security group rules configured

## How IRSA Works

1. **Pod starts** with service account `aws-load-balancer-controller`
2. **EKS injects** environment variables and mounts a token:
   - `AWS_ROLE_ARN`: The IAM role ARN from service account annotation
   - `AWS_WEB_IDENTITY_TOKEN_FILE`: Path to OIDC token file
3. **AWS SDK** automatically uses these to call `sts:AssumeRoleWithWebIdentity`
4. **STS validates** the OIDC token against the EKS OIDC provider
5. **STS returns** temporary AWS credentials (access key, secret key, session token)
6. **Controller uses** these credentials to make AWS API calls

## Benefits of IRSA

✅ **No static credentials** - No need to manage IAM user access keys
✅ **Automatic rotation** - Credentials expire after 1 hour, automatically refreshed
✅ **Pod-level permissions** - Each pod can have different IAM permissions
✅ **Audit trail** - CloudTrail shows which pod assumed which role
✅ **Least privilege** - Each service account gets only required permissions

## Security Group Configuration

When using TargetGroupBinding with `targetType: ip`, the ALB must be able to reach pod IPs directly. This requires security group rules on the **EKS node security group** (not just the backend pods security group).

### Required Security Group Rules

The following security group rules are configured in `vpc_security_groups.tf`:

```hcl
# Allow ALB to reach backend pods on port 8787
resource "aws_security_group_rule" "eks_nodes_from_alb_backend" {
  type                     = "ingress"
  from_port                = 8787
  to_port                  = 8787
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb[0].id
  security_group_id        = module.eks[0].node_security_group_id
  description              = "Backend API port from ALB (for pod IPs)"
}

# Allow ALB to reach frontend pods on port 8080
resource "aws_security_group_rule" "eks_nodes_from_alb_frontend" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb[0].id
  security_group_id        = module.eks[0].node_security_group_id
  description              = "Frontend port from ALB (for pod IPs)"
}
```

**Why node security group?** When using `targetType: ip`, pods get IP addresses from the VPC subnet (via VPC CNI). The ALB health checks and traffic go directly to these pod IPs, which are subject to the EC2 instance (EKS node) security group rules.

## Troubleshooting

### Controller pods not starting

```bash
# Check service account exists
kubectl get sa aws-load-balancer-controller -n kube-system

# Check role annotation
kubectl get sa aws-load-balancer-controller -n kube-system -o yaml | grep role-arn

# Check OIDC provider exists
aws iam list-open-id-connect-providers | grep eks
```

### Pods failing with "AccessDenied"

```bash
# Check IAM role trust policy
aws iam get-role --role-name shovel-heros-staging-alb-controller-...

# Check IAM policy is attached
aws iam list-attached-role-policies --role-name shovel-heros-staging-alb-controller-...

# Check pod can assume role
kubectl exec -it <pod-name> -n kube-system -- env | grep AWS
```

### Targets not registering

```bash
# Check TargetGroupBinding status
kubectl describe targetgroupbinding backend-tgb -n shovel-heroes

# Check controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify service exists and has endpoints
kubectl get svc backend -n shovel-heroes
kubectl get endpoints backend -n shovel-heroes
```

## References

- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [TargetGroupBinding CRD Reference](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.13/guide/targetgroupbinding/targetgroupbinding/)

## Terraform Files

- **`iam_alb_controller.tf`**: IRSA resources (IAM role, policy, service account)
- **`versions.tf`**: Provider requirements (http, kubernetes)
- **`provider.tf`**: Kubernetes provider configuration
- **`data.tf`**: EKS cluster data sources for provider authentication
- **`outputs.tf`**: `alb_controller_role_arn` output
