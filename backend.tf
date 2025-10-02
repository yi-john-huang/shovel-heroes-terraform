terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket-example"
    key            = "infrastructure/terraform.tfstate"
    region         = "ap-northeast-2" # Seoul, South Korea
    encrypt        = true
    use_lockfile   = true
    dynamodb_table = "terraform-state-lock"
  }
}