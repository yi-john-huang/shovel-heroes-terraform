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
  alias  = "taipei"
  region = "ap-east-1" # Hong Kong

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = local.env_type
      ManagedBy   = "terraform"
      Region      = "taipei"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
