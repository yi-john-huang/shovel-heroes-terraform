provider "aws" {
  region = var.primary_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = local.env_type
      ManagedBy   = "terraform"
    }
  }
}

provider "aws" {
  alias                  = "taipei"
  region                 = "ap-east-2" # Taipei, Taiwan
  skip_region_validation = true        # not support Taipei region at the moment

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = local.env_type
      ManagedBy   = "terraform"
      Region      = "taipei"
    }
  }
}

# CloudFront requires ACM certificates to be in us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = local.env_type
      ManagedBy   = "terraform"
    }
  }
}
