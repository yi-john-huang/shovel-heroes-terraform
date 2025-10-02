terraform {
  backend "s3" {
    bucket                     = "shovel-heros-terraform-state-bucket"
    key                        = "infrastructure/terraform.tfstate"
    region                     = "ap-east-2" # Taipei, Taiwan
    skip_region_validation     = true
    skip_requesting_account_id = true
    skip_s3_checksum           = true
    encrypt                    = true
    use_lockfile               = true
  }
}