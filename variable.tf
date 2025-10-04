variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "my-terraform-project"
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "ap-east-2" # Taipei, Taiwan
}

variable "aws_region" {
  description = "AWS region for resource deployment (alias for primary_region)"
  type        = string
  default     = "ap-east-2"
}

variable "environment" {
  description = "Environment name (e.g., development, staging, production)"
  type        = string
  default     = "production"
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
    database_password      = string
    line_channel_id        = optional(string, "")
    line_channel_secret    = optional(string, "")
    turnstile_secret_key   = optional(string, "")
  })
  sensitive = true
  default = {
    database_password = ""
  }
}

variable "domain_name" {
  description = "Domain name for the application (required for HTTPS/ACM certificate)"
  type        = string
  default     = ""

  validation {
    condition     = var.domain_name == "" || can(regex("^[a-z0-9-]+(\\.[a-z0-9-]+)+$", var.domain_name))
    error_message = "Domain name must be a valid DNS name (e.g., example.com)"
  }
}


variable "ssh_key_name" {
  description = "SSH key pair name for bastion host access"
  type        = string
  default     = "" # Leave empty to skip bastion creation
}

variable "admin_ip" {
  description = "Admin IP address for bastion SSH access (CIDR format)"
  type        = string
  default     = "0.0.0.0/0" # Restrict this to your IP in production
}
