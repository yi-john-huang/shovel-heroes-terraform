# Security Guide

This document outlines the credential protection measures implemented in this Terraform project.

## Multi-Layer Credential Protection

### 1. File Exclusions
- **`.gitignore`** - Prevents credentials from being committed to Git
- **`.kiro-ignore`** - Protects credentials from Kiro AI assistant
- **`.claude/settings.local.json`** - Excludes credentials from Claude Code

### 2. Secure Directory Structure
- `secrets/` directory with 700 permissions (owner access only)
- Subdirectories for different credential types
- Template files for safe credential setup

### 3. Credential Templates
- `.env.template` - Environment variable template
- `terraform.tfvars.template` - Terraform variables template  
- `secrets/aws/credentials.template` - AWS credentials template

### 4. Security Scripts
- `scripts/load-credentials.sh` - Secure credential loading
- `scripts/validate-credentials.sh` - Security validation
- `scripts/rotate-credentials.sh` - Credential rotation helper
- `scripts/install-pre-commit.sh` - Pre-commit hook setup

### 5. Automated Protection
- Pre-commit hooks for secret detection
- Automated credential scanning with detect-secrets and TruffleHog
- File permission validation
- Placeholder value detection

## Quick Setup

1. **Install security tools:**
   ```bash
   ./scripts/install-pre-commit.sh
   ```

2. **Create your credentials:**
   ```bash
   cp .env.template .env
   cp terraform.tfvars.template terraform.tfvars
   cp secrets/aws/credentials.template secrets/aws/credentials
   chmod 600 .env terraform.tfvars secrets/aws/credentials
   ```

3. **Fill in actual values** (replace PLACEHOLDER_ and CHANGE_THIS values)

4. **Validate security:**
   ```bash
   ./scripts/validate-credentials.sh
   ```

5. **Load credentials for Terraform:**
   ```bash
   source ./scripts/load-credentials.sh
   terraform plan
   ```

## Credential Management

### AWS Credentials
- Store in `secrets/aws/credentials` with 600 permissions
- Use AWS profiles for different environments
- Rotate keys regularly: `./scripts/rotate-credentials.sh --rotate aws`

### API Tokens
- Store in `.env` file as environment variables
- Use `TF_VAR_` prefix for Terraform variables
- Rotate tokens regularly: `./scripts/rotate-credentials.sh --rotate github`

### Database Passwords
- Use strong, unique passwords
- Store in `terraform.tfvars` as sensitive variables
- Consider using AWS Secrets Manager for production

## Security Best Practices

1. **Never commit actual credentials** - always use templates
2. **Set proper file permissions** - 600 for files, 700 for directories
3. **Use separate credentials** for different environments
4. **Rotate credentials regularly** - at least quarterly
5. **Monitor for exposed secrets** - pre-commit hooks will help
6. **Use least privilege access** - minimal required permissions
7. **Enable MFA** on all accounts where possible

## Validation Commands

```bash
# Check all security measures
./scripts/validate-credentials.sh

# Test credential validity
./scripts/rotate-credentials.sh --check

# Run pre-commit hooks manually
pre-commit run --all-files

# Scan for secrets in git history
trufflehog git file://. --only-verified
```

## Emergency Response

If credentials are accidentally committed:

1. **Immediately rotate** the exposed credentials
2. **Remove from git history:**
   ```bash
   git filter-branch --force --index-filter \
     'git rm --cached --ignore-unmatch path/to/file' \
     --prune-empty --tag-name-filter cat -- --all
   ```
3. **Force push** to overwrite remote history (if safe to do so)
4. **Review access logs** for any unauthorized usage
5. **Update security measures** to prevent recurrence

## Support

For security questions or issues:
1. Review this documentation
2. Run validation scripts
3. Check pre-commit hook output
4. Ensure all template files are properly configured