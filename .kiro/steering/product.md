# Product Overview

## Product Description
Comprehensive AWS infrastructure for deploying cloud-native applications with enterprise-grade features, focusing on multi-region support with primary deployment in Taiwan (ap-northeast-2).

**Project**: Shovel Heroes Terraform Infrastructure
**Version**: 1.0.0
**Type**: Infrastructure as Code (Terraform)

## Core Features

### Container Orchestration
- **EKS Clusters**: Managed Kubernetes (v1.33) with multiple specialized node groups
  - General purpose SPOT instances for cost optimization
  - Workflow ON_DEMAND instances with taints for workload isolation
  - Scalable compute-intensive node groups

### Multi-Region Support
- Primary region: Taiwan (ap-northeast-2)
- Configurable regional deployments via feature flags
- Multi-AZ deployment for high availability

### CI/CD Infrastructure
- AWS CodePipeline integration
- AWS CodeBuild for automated deployments
- GitHub integration for source control
- Automated build and deployment workflows

### Data Infrastructure
- **RDS**: PostgreSQL 16.8 with encryption and automated backups
- **S3**: Versioned buckets with lifecycle policies and encryption
- **EFS**: Elastic file storage (when enabled)
- Multi-tier storage with archival policies

### Security & Networking
- **VPC**: 10.0.0.0/16 with public/private subnet architecture
- **WAF**: Web Application Firewall protection
- **VPC Endpoints**: Private AWS service access
- **Security Groups**: Tiered access control (external, internal, database)
- Encryption at rest and in transit

### Monitoring & Operations
- **CloudWatch**: Centralized logging and metrics
- **Dashboards**: Real-time infrastructure monitoring
- **Alarms**: CPU and resource utilization alerts
- Comprehensive observability stack

## Target Use Case
Enterprise-grade cloud infrastructure for containerized applications requiring:
- High availability across multiple availability zones
- Cost-optimized compute with SPOT and ON_DEMAND instances
- Secure data storage and processing
- Automated CI/CD pipelines
- Multi-region capability

## Key Value Proposition

### Infrastructure Efficiency
- **Cost Optimization**: SPOT instances for non-critical workloads, S3 lifecycle policies
- **Scalability**: Auto-scaling EKS node groups, configurable capacity
- **High Availability**: Multi-AZ deployment, redundant NAT gateways

### Developer Experience
- **Modular Design**: Feature flags for conditional resource deployment
- **Validation Tooling**: Comprehensive validation scripts with security scanning
- **Clear Documentation**: Steering files guide infrastructure decisions

### Enterprise Features
- **Security First**: Encryption, least-privilege IAM, network isolation
- **Compliance Ready**: Resource tagging, audit logging, cost tracking
- **Production Ready**: Automated backups, disaster recovery, monitoring

## Target Users
- **DevOps Engineers**: Infrastructure deployment and management
- **Platform Teams**: Multi-tenant container orchestration
- **Cloud Architects**: Enterprise infrastructure design
- **Development Teams**: Application deployment on managed infrastructure

## Success Metrics
- Infrastructure deployment success rate
- Cost per workload optimization
- System uptime and availability (SLA targets)
- Deployment automation efficiency
- Security compliance adherence

## Technical Advantages

### Modern Infrastructure Patterns
- Infrastructure as Code with Terraform
- Immutable infrastructure principles
- GitOps-ready architecture

### AWS Best Practices
- Well-Architected Framework alignment
- Cost optimization through right-sizing
- Multi-AZ redundancy
- Security in depth

### Operational Excellence
- Automated validation and testing
- Timestamped plan management
- Comprehensive logging and monitoring
- Security scanning with tfsec
- Cost estimation with infracost
