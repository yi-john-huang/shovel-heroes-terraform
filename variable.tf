variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "my-terraform-project"
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "ap-northeast-2" # Seoul, South Korea
}

variable "env_vars" {
  description = "Environment configuration object"
  type = object({
    env_name = string
    env_type = string
  })
  default = {
    env_name = "development"
    env_type = "dev"
  }
}

variable "secrets" {
  description = "Sensitive values"
  type = object({
    database_password = string
  })
  sensitive = true
  default = {
    database_password = ""
  }
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "your-org"
}

variable "github_token" {
  description = "GitHub token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
  default     = ""
}