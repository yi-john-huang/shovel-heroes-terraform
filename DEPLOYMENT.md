# Shovel Heroes Deployment Guide

This guide covers deploying the Shovel Heroes application to AWS using the Terraform infrastructure.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Infrastructure Deployment](#infrastructure-deployment)
3. [Application Deployment](#application-deployment)
4. [Database Setup](#database-setup)
5. [Accessing the Application](#accessing-the-application)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

- **Terraform** >= 1.9.8
- **AWS CLI** configured with appropriate credentials
- **kubectl** for Kubernetes management
- **Docker** for building container images
- **Node.js** 20.x (for local development)

### AWS Permissions

Your AWS credentials need permissions for:
- EKS cluster management
- RDS database creation
- S3 bucket management
- ECR repository management
- IAM role creation
- VPC and networking resources
- Secrets Manager
- CloudWatch

---

## Infrastructure Deployment

### 1. Configure Variables

Create a `terraform.tfvars` file:

```hcl
project_name = "shovel-heroes"
primary_region = "ap-east-2"

env_vars = {
  env_name = "production"
  env_type = "prod"
}

secrets = {
  database_password = "CHANGE_ME_TO_SECURE_PASSWORD"
}
```

**Important**: Use AWS Secrets Manager or a secure method for the database password in production!

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the Plan

```bash
terraform plan -out=tfplan
```

Review the resources that will be created:
- VPC with public/private subnets across 3 AZs
- EKS cluster (Kubernetes 1.33)
- RDS PostgreSQL 16.8 database
- ECR repositories for container images
- Application Load Balancer
- S3 buckets (frontend, logs, backups)
- Secrets Manager secrets
- IAM roles and policies
- Security groups
- CloudWatch log groups and alarms

### 4. Apply the Infrastructure

```bash
terraform apply tfplan
```

This will take approximately 15-20 minutes, primarily for EKS cluster creation.

### 5. Save the Outputs

```bash
terraform output > infrastructure-outputs.txt
```

Important outputs:
- `ecr_repository_urls` - Where to push Docker images
- `alb_dns_name` - Backend API endpoint
- `rds_address` - Database endpoint
- `database_secret_arn` - Secrets Manager ARN for DB credentials
- `kubectl_config_command` - Command to configure kubectl

---

## Application Deployment

### 1. Configure kubectl for EKS

```bash
# Get the command from Terraform outputs
terraform output -raw kubectl_config_command | bash

# Verify connection
kubectl get nodes
```

### 2. Install AWS Load Balancer Controller

The AWS Load Balancer Controller is required to connect Kubernetes services to the ALB target groups created by Terraform.

```bash
# Add the EKS Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install the AWS Load Balancer Controller
# The IAM role and service account are already created by Terraform
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$(terraform output -raw eks_cluster_name) \
  --set region=$(terraform output -raw primary_region) \
  --set vpcId=$(terraform output -raw vpc_id) \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Verify the controller is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

**Note**: The Terraform configuration has already created:
- IAM policy with ALB controller permissions
- IAM role with IRSA (OIDC trust relationship)
- Kubernetes service account with role annotation

See `iam_alb_controller.tf` for the IRSA setup details.

### 3. Build and Push Docker Images

#### Backend API

```bash
cd /path/to/shovel-heroes/packages/backend

# Build the image
docker build -t shovel-heroes-backend:latest .

# Get ECR login
aws ecr get-login-password --region ap-east-2 | docker login --username AWS --password-stdin <ECR_URL>

# Tag and push
ECR_BACKEND=$(terraform output -json ecr_repository_urls | jq -r '.["shovel-heroes-backend"]')
docker tag shovel-heroes-backend:latest $ECR_BACKEND:latest
docker tag shovel-heroes-backend:latest $ECR_BACKEND:v1.0.0
docker push $ECR_BACKEND:latest
docker push $ECR_BACKEND:v1.0.0
```

#### Frontend (Container deployment)

```bash
cd /path/to/shovel-heroes

# Build the React app
npm run build

# Build and push frontend image
docker build -t shovel-heroes-frontend:latest .
ECR_FRONTEND=$(terraform output -json ecr_repository_urls | jq -r '.["shovel-heroes-frontend"]')
docker tag shovel-heroes-frontend:latest $ECR_FRONTEND:latest
docker push $ECR_FRONTEND:latest
```

### 4. Create Kubernetes Namespace

```bash
kubectl create namespace shovel-heroes
```

### 5. Deploy Kubernetes Resources

The ALB and target groups are already created by Terraform. Use TargetGroupBinding CRDs to connect Kubernetes services to the existing ALB target groups.

Create `k8s/backend-deployment.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: shovel-heroes

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: shovel-heroes-backend
  namespace: shovel-heroes
  annotations:
    eks.amazonaws.com/role-arn: <BACKEND_POD_ROLE_ARN>  # From: terraform output -raw backend_pod_role_arn

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: shovel-heroes
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      serviceAccountName: shovel-heroes-backend
      containers:
      - name: backend
        image: <ECR_BACKEND_URL>:latest  # From Terraform output
        ports:
        - containerPort: 8787
          name: http
        env:
        - name: PORT
          value: "8787"
        - name: NODE_ENV
          value: "production"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: database_url
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"

---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: shovel-heroes
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:
  - port: 8787
    targetPort: 8787
    protocol: TCP

---
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: backend-tgb
  namespace: shovel-heroes
spec:
  serviceRef:
    name: backend
    port: 8787
  targetGroupARN: <BACKEND_TG_ARN>  # From: terraform output -raw backend_target_group_arn
  targetType: ip
```

Create `k8s/frontend-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: shovel-heroes
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: <ECR_FRONTEND_URL>:latest  # From Terraform output
        ports:
        - containerPort: 80
          name: http
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"

---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: shovel-heroes
spec:
  type: ClusterIP
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP

---
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: frontend-tgb
  namespace: shovel-heroes
spec:
  serviceRef:
    name: frontend
    port: 80
  targetGroupARN: <FRONTEND_TG_ARN>  # From: terraform output -raw frontend_target_group_arn
  targetType: ip
```

Apply the configurations:

```bash
# Deploy backend
kubectl apply -f k8s/backend-deployment.yaml

# Deploy frontend
kubectl apply -f k8s/frontend-deployment.yaml

# Verify TargetGroupBindings
kubectl get targetgroupbindings -n shovel-heroes

# Check if pods are registered with ALB target groups
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw backend_target_group_arn) \
  --region ap-east-2
```

**Important**: The Terraform-created ALB has listener rules configured for:
- Priority 50 (HTTPS): `api.shovel-heroes.cc` (all paths) → Backend target group
- Priority 100 (HTTPS): `shovel-heroes.cc` + `/api/*`, `/healthz`, `/docs/*` → Backend target group
- Priority 200 (HTTPS): `shovel-heroes.cc` + `/*` → Frontend target group
- HTTP listener: Redirects to HTTPS (301)

### 5. Create Kubernetes Secrets from AWS Secrets Manager

First, install External Secrets Operator (recommended):

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace
```

Or manually create secrets:

```bash
# Get database URL from Secrets Manager
DB_SECRET_ARN=$(terraform output -raw database_secret_arn)
DB_URL=$(aws secretsmanager get-secret-value --secret-id $DB_SECRET_ARN --query SecretString --output text | jq -r '.database_url')

# Create Kubernetes secret
kubectl create secret generic database-credentials \
  --from-literal=database_url="$DB_URL" \
  -n shovel-heroes
```

---

## Database Setup

### 1. Connect to Database

```bash
# Get connection details
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
DB_NAME=$(terraform output -raw rds_database_name)

# Connect via psql
psql -h $RDS_ENDPOINT -U dbadmin -d $DB_NAME
```

### 2. Initialize Database Schema

Run the initialization SQL from your application:

```bash
# From the backend directory
cd packages/backend

# The application should auto-create tables on first run
# Or manually run the schema from db-init.ts
```

### 3. Verify Tables

```sql
\dt  -- List all tables

-- Should see:
-- disaster_areas
-- users
-- grids
-- volunteer_registrations
-- supply_donations
-- grid_discussions
-- announcements
```

---

## Database Tunnel Access

For secure database access, use the SSM-based bastion host created by Terraform:

```bash
# Run the automated tunnel script
cd /path/to/shovel-heroes-terraform
./scripts/db-tunnel.sh

# This will:
# - Get bastion instance ID and RDS endpoint from Terraform outputs
# - Retrieve database password from Secrets Manager
# - Copy password to clipboard (macOS)
# - Start SSM port forwarding session (localhost:5433 → RDS:5432)

# Then connect with pgAdmin or psql:
psql -h localhost -p 5433 -U dbadmin -d shovelheroes
```

See `scripts/README.md` for more details on the database tunnel.

---

## Accessing the Application

### Backend API

The backend API is accessible via the ALB with **host-based routing**:

```bash
# Get the API domain (Route53 configured)
API_DOMAIN=$(terraform output -raw api_domain)

# Test backend health
curl https://$API_DOMAIN/healthz
# Response: {"status":"ok","db":"ready"}

# Test API endpoints
curl https://$API_DOMAIN/api/disasters
```

### Frontend

The frontend is served via the same ALB on the root domain:

```bash
# Get the domain name
DOMAIN=$(terraform output -raw domain_name)

# Access frontend
echo "Frontend: https://$DOMAIN"
echo "Backend API: https://api.$DOMAIN"
```

**Current Setup** (Fully Deployed):
- ✅ Domain: `shovel-heroes.cc` (registered via Route53)
- ✅ Frontend: `https://shovel-heroes.cc` → ALB → Frontend pods (nginx on port 8080)
- ✅ Backend API: `https://api.shovel-heroes.cc` → ALB → Backend pods (port 8787)
- ✅ ACM Certificate: Valid for `*.shovel-heroes.cc` and `shovel-heroes.cc`
- ✅ HTTPS: Enforced with HTTP→HTTPS redirect
- ✅ Security: ClusterIP services with TargetGroupBinding (targetType: ip)

**Routing Configuration**:
- **Host-based routing** (priority 50): `api.shovel-heroes.cc` → Backend target group
- **Path-based routing** (priority 100): `shovel-heroes.cc/api/*`, `/healthz`, `/docs/*` → Backend target group
- **Catch-all routing** (priority 200): `shovel-heroes.cc/*` → Frontend target group

### API Documentation

Access Swagger UI (if implemented):
```bash
# API documentation
curl https://api.shovel-heroes.cc/docs

# Health check
curl https://api.shovel-heroes.cc/healthz
```

---

## Environment Variables

The backend pods need these environment variables (configured in Kubernetes deployment):

```yaml
env:
  - name: PORT
    value: "8787"
  - name: NODE_ENV
    value: "production"
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: database-credentials
        key: database_url
```

---

## Monitoring

### CloudWatch Logs

```bash
# View EKS logs
aws logs tail /aws/eks/shovel-heroes-prod-eks/cluster --follow

# View application logs
aws logs tail /aws/application/shovel-heroes-prod --follow
```

### CloudWatch Dashboards

Navigate to AWS Console → CloudWatch → Dashboards → `shovel-heroes-prod-dashboard`

### Metrics

Key metrics to monitor:
- ALB target health count
- ALB response time
- RDS CPU utilization
- RDS connection count
- EKS node CPU/Memory

---

## Scaling

### Backend Horizontal Scaling

```bash
# Scale backend deployment
kubectl scale deployment backend -n shovel-heroes --replicas=5

# Or use HPA (Horizontal Pod Autoscaler)
kubectl autoscale deployment backend -n shovel-heroes \
  --cpu-percent=70 \
  --min=2 \
  --max=10
```

### Database Scaling

For RDS, update `local.tf`:
```hcl
rds_instance_class = "db.t3.large"  # Upgrade instance type
```

Then run:
```bash
terraform apply
```

---

## Troubleshooting

### Pods not starting

```bash
# Check pod status
kubectl get pods -n shovel-heroes

# View pod logs
kubectl logs -f deployment/backend -n shovel-heroes

# Describe pod for events
kubectl describe pod <pod-name> -n shovel-heroes
```

### Database connection issues

```bash
# Verify security groups
# Backend pods should be in backend_pods security group
# RDS should allow connections from backend_pods security group

# Test from a pod
kubectl run -it --rm debug --image=postgres:16 -n shovel-heroes -- bash
psql -h <RDS_ENDPOINT> -U dbadmin -d shovelheroes
```

### ALB not routing traffic

```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw backend_target_group_arn)

# Should show "healthy" status
```

### ECR push failed

```bash
# Re-authenticate to ECR
aws ecr get-login-password --region ap-east-2 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-east-2.amazonaws.com
```

---

## Cleanup

To destroy all infrastructure:

```bash
# Delete Kubernetes resources first
kubectl delete namespace shovel-heroes

# Wait for load balancers to be deleted (important!)
sleep 60

# Destroy Terraform resources
terraform destroy
```

**Warning**: This will delete all data including the database!

---

## CI/CD with GitHub Actions

This infrastructure is designed to work with GitHub Actions for continuous deployment. The Terraform configuration creates:

1. **GitHub Actions OIDC Provider**: Allows GitHub Actions to authenticate to AWS without storing credentials
2. **GitHub Actions IAM Role**: Grants permissions for ECR push, EKS deployment, S3 upload, and CloudFront invalidation

### Setting up GitHub Actions

1. **Get the IAM Role ARN**:
```bash
terraform output -raw github_actions_role_arn
```

2. **Configure GitHub Secrets**:
   - `AWS_REGION`: Your deployment region (e.g., `ap-east-2`)
   - `AWS_ROLE_ARN`: The role ARN from step 1

3. **Sample GitHub Actions Workflow** (`.github/workflows/deploy.yml`):

```yaml
name: Deploy to EKS

on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build and push backend
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          cd packages/backend
          docker build -t $ECR_REGISTRY/shovel-heroes-prod-shovel-heroes-backend:$IMAGE_TAG .
          docker push $ECR_REGISTRY/shovel-heroes-prod-shovel-heroes-backend:$IMAGE_TAG

      - name: Deploy to EKS
        run: |
          aws eks update-kubeconfig --name shovel-heroes-prod-eks --region ${{ secrets.AWS_REGION }}
          kubectl set image deployment/backend backend=${{ steps.login-ecr.outputs.registry }}/shovel-heroes-prod-shovel-heroes-backend:${{ github.sha }} -n shovel-heroes
```

---

## Next Steps

1. **Set up CI/CD**: Configure GitHub Actions using the OIDC provider created by Terraform
2. **Add monitoring alerts**: Set up SNS notifications for CloudWatch alarms
3. **Configure custom domain**: Use Route53 and ACM for SSL/TLS
4. **Enable CloudFront**: For better frontend performance
5. **Implement backups**: Automated database backup strategy
6. **Add WAF rules**: Protect against common web attacks

---

## Support

For issues or questions:
- Check Terraform state: `terraform show`
- Review CloudWatch Logs
- Check AWS Console for resource status
- Review `.kiro/steering/` documentation
