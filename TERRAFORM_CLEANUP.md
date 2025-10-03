# Terraform Cleanup Instructions

## Overview
Remove unused S3/CloudFront resources since frontend will be deployed to EKS as a containerized Nginx service instead of static S3 hosting.

## Repository Location
`/Users/yihuang/workspace/shovel-heroes-terraform`

---

## Resources to Remove

### 1. S3 Frontend Bucket
**Files to modify**: `s3.tf` or `s3_website.tf`

Remove:
- `aws_s3_bucket.frontend[0]`
- `aws_s3_bucket_website_configuration.frontend[0]`
- `aws_s3_bucket_public_access_block.frontend[0]`
- `aws_s3_bucket_policy.frontend[0]`
- Any KMS key specifically for frontend S3 encryption

**Keep**:
- `aws_s3_bucket.backups` (for database backups)
- `aws_s3_bucket.logs` (for ALB/application logs)

### 2. CloudFront Distribution
**File**: `cloudfront.tf`

Remove entire file or specific resources:
- `aws_cloudfront_distribution.frontend[0]`
- `aws_cloudfront_origin_access_control.frontend[0]`
- CloudFront logging bucket (if dedicated)

### 3. ACM Certificate (us-east-1)
**File**: `acm.tf`

Review and potentially remove:
- ACM certificate for CloudFront in `us-east-1` region
- **Keep** ALB certificate in `ap-east-2` region

### 4. IAM Policies
**File**: `iam_app.tf`

Remove policies related to:
- S3 frontend bucket access (`aws_iam_policy.backend_s3` - only frontend portions)
- CloudFront invalidation permissions

Example resources to remove:
```hcl
# Remove or modify this section
resource "aws_iam_policy" "backend_s3" {
  # Remove S3 frontend bucket permissions
  # Keep S3 backups bucket permissions
}
```

### 5. Terraform Outputs
**File**: `outputs.tf`

Remove outputs:
- `frontend_bucket_name`
- `frontend_bucket_regional_domain`
- `cloudfront_distribution_id`
- `cloudfront_domain_name`
- `frontend_url` (or modify to use ALB DNS)

**Keep**:
- `alb_dns_name` - Will be used for both frontend and backend
- `backups_bucket_name`
- All EKS, RDS, ECR outputs

---

## Resources to Keep/Modify

### ALB Configuration
**File**: `alb.tf`

**Current state**: Single backend target group (port 8787)

**Required changes**:
1. Keep existing backend target group
2. Add frontend target group (port 80)
3. Configure path-based routing:
   - `/api/*` → Backend target group
   - `/*` → Frontend target group

Example modifications needed in `alb.tf`:
```hcl
# Keep existing backend target group
resource "aws_lb_target_group" "backend" {
  # ... existing configuration
}

# ADD: Frontend target group
resource "aws_lb_target_group" "frontend" {
  count = local.alb_enabled ? 1 : 0

  name     = "${var.project_name}-${local.env_type}-frontend-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${local.env_type}-frontend-target-group"
  })
}

# MODIFY: Listener rules for path-based routing
resource "aws_lb_listener_rule" "api" {
  count = local.alb_enabled ? 1 : 0

  listener_arn = aws_lb_listener.http[0].arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend[0].arn
  }

  condition {
    path_pattern {
      values = ["/api/*", "/healthz"]
    }
  }
}

resource "aws_lb_listener_rule" "frontend" {
  count = local.alb_enabled ? 1 : 0

  listener_arn = aws_lb_listener.http[0].arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend[0].arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}
```

### ECR Repositories
**File**: `ecr.tf`

**No changes needed** - Both repositories already exist:
- `shovel-heroes-{env}-shovel-heroes-backend`
- `shovel-heroes-{env}-shovel-heroes-frontend`

The frontend repo will now be used for Nginx container images instead of being unused.

---

## Step-by-Step Cleanup Procedure

### 1. Backup Current State
```bash
cd /Users/yihuang/workspace/shovel-heroes-terraform

# Create backup branch
git checkout -b cleanup/remove-s3-cloudfront

# Backup current state
terraform state pull > terraform.tfstate.backup
```

### 2. Remove CloudFront Resources
```bash
# Remove CloudFront file
rm -f cloudfront.tf

# Or edit to comment out/remove CloudFront resources
```

### 3. Edit S3 Resources
```bash
# Edit s3.tf or s3_website.tf
# Remove frontend bucket resources
# Keep backups and logs buckets
```

### 4. Edit IAM Policies
```bash
# Edit iam_app.tf
# Remove S3 frontend and CloudFront policies
# Keep backend S3 access to backups bucket
```

### 5. Edit Outputs
```bash
# Edit outputs.tf
# Remove frontend_bucket_name, cloudfront_distribution_id, etc.
# Keep alb_dns_name and other outputs
```

### 6. Update ALB Configuration
```bash
# Edit alb.tf
# Add frontend target group
# Add path-based routing rules
```

### 7. Review Local Variables
```bash
# Edit local.tf
# Verify feature flags are correct
# May need to remove cloudfront_enabled or similar flags
```

### 8. Plan Changes
```bash
terraform fmt
terraform validate
terraform plan -out=cleanup.tfplan

# Review the plan carefully:
# - Should destroy: CloudFront distribution, S3 frontend bucket
# - Should create: Frontend ALB target group, listener rules
# - Should keep: Everything else
```

### 9. Apply Changes
```bash
# Only proceed if plan looks correct
terraform apply cleanup.tfplan
```

### 10. Verify Cleanup
```bash
# Check no S3 frontend bucket
terraform state list | grep -E "s3.*frontend"
# Should show nothing

# Check no CloudFront
terraform state list | grep cloudfront
# Should show nothing

# Check ALB target groups exist
terraform state list | grep target_group
# Should show BOTH backend and frontend target groups

# Verify outputs
terraform output
# Should NOT include frontend_bucket_name or cloudfront_distribution_id
# SHOULD include alb_dns_name
```

### 11. Commit Changes
```bash
git add .
git commit -m "refactor: remove S3/CloudFront, deploy frontend to EKS with path-based ALB routing"
git push origin cleanup/remove-s3-cloudfront

# Create PR for review if needed
```

---

## Validation Checklist

After cleanup, verify:

- [ ] CloudFront distribution removed from AWS Console
- [ ] S3 frontend bucket removed (or no longer exists)
- [ ] S3 backups bucket still exists
- [ ] ALB has TWO target groups: backend (8787) and frontend (80)
- [ ] ALB listener rules configured for path-based routing
- [ ] ECR repositories for both backend and frontend exist
- [ ] Terraform outputs no longer include S3/CloudFront frontend resources
- [ ] `alb_dns_name` output exists and is accessible
- [ ] No Terraform state errors: `terraform plan` shows no changes

---

## Rollback Plan

If issues occur:

```bash
# Restore from backup
terraform state push terraform.tfstate.backup

# Or restore from Git
git checkout main
git branch -D cleanup/remove-s3-cloudfront

# Re-apply previous working state
terraform apply
```

---

## Notes

- This cleanup is **prerequisite** to deploying frontend to EKS
- After cleanup, frontend will be served from Nginx containers in EKS
- Single ALB endpoint will serve both frontend (`/*`) and backend (`/api/*`)
- Cost savings: Remove CloudFront (if not in free tier) and S3 website hosting
- Simplified architecture: All services in EKS, no separate S3/CDN management
