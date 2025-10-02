# Terraform Infrastructure Project

## Project Documentation

For comprehensive project information, refer to the steering files in `./.kiro/steering/`:

- **`./.kiro/steering/product.md`** - Product overview, features, and platform design
- **`./.kiro/steering/structure.md`** - Project structure, naming conventions, and architecture patterns
- **`./.kiro/steering/tech.md`** - Technology stack, common commands, and development workflow

## Quick Commands

```bash
# Format and validate
terraform fmt
terraform validate

# Comprehensive validation with plan generation
./scripts/validate.sh

# Standard workflow
terraform init
terraform plan
terraform apply

# Apply from saved plan
terraform apply "plans/tfplan_YYYYMMDD_HHMMSS.out"
```