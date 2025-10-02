# Terraform Infrastructure Skeleton

A comprehensive Terraform configuration for deploying cloud-native applications on AWS with multi-region support, focusing on Taiwan region (ap-northeast-2).

## Architecture Overview

This infrastructure supports scalable applications with enterprise-grade features:

- **EKS clusters** for container orchestration with Amazon Linux 2023 node groups
- **Multi-region support** with configurable regional deployments
- **CI/CD pipelines** using GitHub Actions with OIDC authentication
- **Data processing infrastructure** including RDS databases and S3
- **Security features** with Secrets Manager, IAM roles, and security groups
- **Monitoring and alerting** through CloudWatch

## Project Structure

```
.
├── CLAUDE.md                    # Project instructions and quick commands
├── README.md                    # This file
├── .gitignore                   # Git ignore patterns
├── terraform.tfvars.example     # Example configuration file
├── scripts/
│   └── validate.sh              # Terraform validation and planning script
├── versions.tf                  # Terraform and provider version constraints
├── provider.tf                  # Provider configurations (AWS, Cloudflare, GitHub)
├── backend.tf                   # S3 backend configuration
├── variable.tf                  # Input variable declarations
├── local.tf                     # Local value definitions and feature flags
├── data.tf                      # Data source definitions
├── vpc.tf                       # VPC, subnets, routing
├── vpc_security_groups.tf       # Security groups for different tiers
├── eks.tf                       # EKS cluster with AL2023 node groups
├── iam_eks.tf                   # IAM roles for EKS
├── iam_app.tf                   # IAM roles for application (GitHub Actions, pods)
├── rds.tf                       # PostgreSQL database configuration
├── s3.tf                        # S3 buckets with lifecycle policies
├── cloudwatch.tf               # Monitoring, logging, and dashboards
├── outputs.tf                   # Resource outputs
├── plans/                       # Generated Terraform plans (gitignored)
├── logs/                        # Validation and execution logs (gitignored)
└── .kiro/steering/             # Project steering documentation
    ├── product.md              # Product overview and features
    ├── structure.md            # Project structure and conventions
    └── tech.md                 # Technology stack and commands
```

## Quick Start

### Prerequisites

- Terraform >= 1.9.8
- AWS CLI configured with appropriate credentials
- Access to Taiwan region (ap-northeast-2)

### Deployment

1. **Initialize Terraform:**
   ```bash
   terraform init
   ```

2. **Review and customize variables:**
   ```bash
   # Edit variables in variable.tf or create terraform.tfvars
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your specific values
   ```

3. **Validate and plan the deployment:**
   ```bash
   # Use the comprehensive validation script
   ./scripts/validate.sh
   
   # Or use standard terraform commands
   terraform plan
   ```

4. **Apply the configuration:**
   ```bash
   # Apply from saved plan (recommended)
   terraform apply "plans/tfplan_YYYYMMDD_HHMMSS.out"
   
   # Or apply directly
   terraform apply
   ```

### Essential Commands

```bash
# Comprehensive validation with plan generation
./scripts/validate.sh

# Format and validate
terraform fmt
terraform validate

# Standard workflow
terraform init
terraform plan
terraform apply

# Apply from saved plan
terraform apply "plans/tfplan_YYYYMMDD_HHMMSS.out"

# Destroy resources (use with caution)
terraform destroy
```

## Validation Script

The `scripts/validate.sh` script provides comprehensive Terraform validation with the following features:

### What it does:
1. **Format check** - Validates and fixes Terraform formatting
2. **Configuration validation** - Ensures syntax and logic are correct
3. **Plan generation** - Creates timestamped plan files in `plans/`
4. **Detailed logging** - Saves all output to timestamped log files in `logs/`
5. **Security scanning** - Runs `tfsec` if available
6. **Cost estimation** - Generates cost estimates with `infracost` if available
7. **Cleanup** - Automatically removes old plan and log files (keeps last 10)

### Usage:
```bash
# Run comprehensive validation
./scripts/validate.sh

# Apply from generated plan
terraform apply "plans/tfplan_20231215_143022.out"
```

### Optional tools:
- **tfsec**: Install with `brew install tfsec` for security scanning
- **infracost**: Install from [infracost.io](https://www.infracost.io/docs/#quick-start) for cost estimation

## Configuration

### Environment Variables

Create a `terraform.tfvars` file with your specific values:

```hcl
project_name = "my-app"
primary_region = "ap-northeast-2"

env_vars = {
  env_name = "production"
  env_type = "prod"
}

secrets = {
  database_password = "your-secure-password"
}

github_org = "your-github-org"
github_token = "your-github-token"
cloudflare_api_token = "your-cloudflare-token"
```

### Feature Flags

Control which components to deploy using local values in `local.tf`:

```hcl
locals {
  eks_enabled    = true   # Deploy EKS cluster
  rds_enabled    = true   # Deploy RDS database
  s3_enabled     = true   # Deploy S3 buckets
  taipei_enabled = true   # Deploy Taiwan region resources
}
```

## Infrastructure Components

### Networking
- **VPC:** 10.0.0.0/16 with public and private subnets across 3 AZs
- **NAT Gateways:** One per AZ for high availability
- **Security Groups:** Tiered access (external, internal, RDS)

### Compute
- **EKS Cluster:** Kubernetes 1.33 with managed node groups on Amazon Linux 2023:
  - **General:** SPOT instances for cost optimization
  - **Workflow:** ON_DEMAND with taints for isolation
  - **Compute:** Scalable compute-intensive workloads

### CI/CD
- **GitHub Actions OIDC:** Secure authentication without AWS credentials
- **IAM Roles:** Granular permissions for ECR, EKS, S3, and CloudFront
- **Automated Deployments:** Push to ECR and deploy to EKS via kubectl

### Data Storage
- **RDS:** PostgreSQL 16.8 with encryption and automated backups
- **S3:** Versioned buckets with lifecycle policies and encryption

### Monitoring
- **CloudWatch:** Centralized logging and metrics
- **Dashboards:** Real-time infrastructure monitoring
- **Alarms:** CPU and resource utilization alerts

## Building from Scratch with CLAUDE.md

This project was built following the steering documentation pattern using Claude Code. Here's how to recreate or extend this infrastructure:

### 1. Project Foundation

The project starts with `CLAUDE.md` which contains:
- Quick reference commands
- Links to detailed steering documentation in `.kiro/steering/`
- Important instruction reminders

### 2. Steering Documentation

Three key files guide the project structure:

**`.kiro/steering/product.md`** - Defines what we're building:
- Product overview and features
- Target platform (AWS with multi-region)
- Core services (EKS, RDS, S3, etc.)

**`.kiro/steering/structure.md`** - Defines how we organize:
- File naming conventions
- Resource organization patterns
- Architecture patterns (conditional resources, multi-region)

**`.kiro/steering/tech.md`** - Defines technical stack:
- Terraform version constraints
- Provider versions
- Common commands and workflow

### 3. Code Generation Process

With Claude Code, you can generate infrastructure by:

1. **Reading the steering files** to understand requirements
2. **Following naming conventions** from structure.md
3. **Using technology constraints** from tech.md
4. **Implementing features** described in product.md

Example prompt for extending this project:
```
Please add Lambda functions for data processing based on the project steering files
```

Claude will:
- Read the steering documentation
- Follow established patterns
- Create `lambda.tf` with appropriate naming
- Add IAM roles in `iam_lambda.tf`
- Update locals and variables as needed

### 4. Extending the Infrastructure

To add new components:

1. **Update steering docs** if adding new product features
2. **Add feature flags** in `local.tf`
3. **Create resource files** following naming patterns
4. **Add IAM roles** in separate `iam_*.tf` files
5. **Update outputs** for new resources

### 5. Best Practices

- **Version control steering docs** alongside infrastructure code
- **Use feature flags** for optional components
- **Follow naming conventions** consistently
- **Separate concerns** (networking, compute, data, IAM)
- **Document decisions** in steering files

## Security Considerations

- All S3 buckets block public access by default
- RDS instances use encryption at rest
- Security groups follow least privilege principle
- IAM roles have minimal required permissions
- Resources are tagged for compliance and cost tracking

## Cost Optimization

- SPOT instances for non-critical workloads
- S3 lifecycle policies for data archival
- Conditional resource deployment
- Right-sized instances based on environment

## Contributing

1. Review steering documentation in `.kiro/steering/`
2. Follow established naming conventions
3. Test changes with `terraform plan`
4. Update documentation when adding features

## Support

For issues or questions:
- Check steering documentation first
- Review Terraform plan output
- Validate AWS permissions and quotas
- Ensure region availability (ap-northeast-2)