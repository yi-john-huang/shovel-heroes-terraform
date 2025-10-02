# Technology Stack

## Architecture
**Type**: Infrastructure as Code (Terraform)
**Cloud Provider**: Amazon Web Services (AWS)
**Primary Region**: Taiwan (ap-east-2)
**Multi-Region Support**: Yes

## Terraform Configuration

### Version Requirements
- **Terraform**: >= 1.9.8
- **AWS Provider**: ~> 6.14.0
- **Cloudflare Provider**: ~> 5.10.0
- **GitHub Provider**: ~> 6.6.0

### Terraform Modules
- **EKS Module**: terraform-aws-modules/eks/aws ~> 21.0
- **VPC**: Custom configuration with multi-AZ support
- Additional AWS service modules as needed

## Technology Stack

### Infrastructure Components

#### Compute & Orchestration
- **Amazon EKS**: Kubernetes v1.33 for container orchestration
- **EC2 Node Groups**:
  - SPOT instances (t3.medium) for cost optimization
  - ON_DEMAND instances (t3.large, t3.xlarge) for critical workloads
  - Compute-optimized instances for intensive workloads

#### Networking
- **Amazon VPC**: 10.0.0.0/16 CIDR
- **Subnets**: Public and private across 3 availability zones
- **NAT Gateway**: High-availability configuration per AZ
- **Security Groups**: Multi-tier architecture (external, internal, database)
- **VPC Endpoints**: Private AWS service access

#### Data Storage
- **Amazon RDS**: PostgreSQL 16.8 with encryption
- **Amazon S3**: Versioned buckets with lifecycle policies
- **Amazon EFS**: Elastic file storage (conditional)
- Encryption at rest for all data stores

#### CI/CD & Development
- **AWS CodePipeline**: Automated deployment workflows
- **AWS CodeBuild**: Build and test automation
- **GitHub Integration**: Source control and webhooks
- **Cloudflare**: DNS and CDN management

#### Monitoring & Operations
- **Amazon CloudWatch**: Centralized logging and metrics
- **CloudWatch Dashboards**: Real-time monitoring
- **CloudWatch Alarms**: Resource utilization alerts
- **CloudWatch Logs**: Application and infrastructure logs

#### Security
- **AWS IAM**: Fine-grained access control
- **AWS WAF**: Web application firewall (conditional)
- **Encryption**: At-rest and in-transit encryption
- **Security Groups**: Network-level security

## Development Environment

### Required Tools
- **Terraform CLI**: >= 1.8.2
- **AWS CLI**: Configured with appropriate credentials
- **Git**: Version control
- **Bash**: For automation scripts

### Optional Tools
- **tfsec**: Security scanning for Terraform code
  - Install: `brew install tfsec`
- **infracost**: Cost estimation for infrastructure changes
  - Install: See [infracost.io/docs](https://www.infracost.io/docs/#quick-start)

### AWS Access Requirements
- Valid AWS credentials configured
- Access to Taiwan region (ap-east-2)
- Appropriate IAM permissions for resource creation
- S3 bucket for Terraform state backend

## Development Commands

### Initialization & Setup
```bash
# Initialize Terraform
terraform init

# Copy and configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### Validation & Planning
```bash
# Comprehensive validation with security scanning and cost estimation
./scripts/validate.sh

# Format Terraform code
terraform fmt

# Validate configuration
terraform validate

# Generate execution plan
terraform plan

# Save plan to file
terraform plan -out=plans/tfplan.out
```

### Deployment
```bash
# Apply infrastructure changes
terraform apply

# Apply from saved plan (recommended)
terraform apply "plans/tfplan_YYYYMMDD_HHMMSS.out"

# Destroy infrastructure (use with caution)
terraform destroy
```

### Utilities
```bash
# View current state
terraform show

# List all resources
terraform state list

# View specific resource
terraform state show <resource_address>

# View outputs
terraform output
```

## Quality Assurance

### Automated Validation
- **Format Check**: `terraform fmt -check -recursive`
- **Configuration Validation**: `terraform validate`
- **Security Scanning**: `tfsec .` (if installed)
- **Cost Estimation**: `infracost breakdown --path .` (if installed)

### Code Review Guidelines
- Follow `.kiro/steering/linus-review.md` standards
- Review security group rules and IAM policies
- Validate resource naming conventions
- Check for sensitive data exposure
- Ensure proper tagging strategy

### Testing Strategy
- Plan review before applying changes
- Validate in non-production environment first
- Monitor CloudWatch metrics post-deployment
- Test disaster recovery procedures

## Deployment Configuration

### Backend Configuration
- **Type**: S3 with DynamoDB state locking
- **State File**: Encrypted in S3
- **Locking**: DynamoDB table for concurrent access prevention
- **Versioning**: Enabled for state file recovery

### Environment Management
- **Feature Flags**: Conditional resource deployment via `local.tf`
- **Environment Variables**: Configured via `terraform.tfvars`
- **Secrets Management**: Sensitive variables marked and secured
- **Multi-Region**: Provider aliases for regional deployments

### Deployment Workflow
1. Update configuration files
2. Run validation script: `./scripts/validate.sh`
3. Review generated plan in `plans/` directory
4. Apply approved changes
5. Verify deployment via CloudWatch
6. Archive plan files (kept for 10 most recent)

### Resource Management
- **Plan Files**: Timestamped and stored in `plans/` directory
- **Log Files**: Timestamped and stored in `logs/` directory
- **State Files**: Managed in S3 backend
- **Cleanup**: Automated removal of old plans and logs (keeps last 10)

## Configuration Files

### Core Files
- `versions.tf`: Version constraints
- `provider.tf`: Provider configurations
- `backend.tf`: Remote state configuration
- `variable.tf`: Input variables
- `outputs.tf`: Output values

### Resource Files
- `vpc.tf`: Network infrastructure
- `vpc_security_groups.tf`: Security groups
- `eks.tf`: Kubernetes cluster
- `rds.tf`: Database configuration
- `s3.tf`: Object storage
- `cloudwatch.tf`: Monitoring and logging
- `iam_*.tf`: IAM roles and policies

### Automation
- `scripts/validate.sh`: Comprehensive validation script
- `terraform.tfvars.example`: Example configuration
- `.gitignore`: Exclude sensitive and generated files
