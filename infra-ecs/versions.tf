# pin the minimum OpenTofu core + provider versions so applies are reproducible
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.67.0"
    }
  }

  # refuse older cores that lack native S3 locking (use_lockfile)
  required_version = "~> 1.12"

  # S3 backend to manage and store state
  backend "s3" {
    bucket = "orbit-tfstate-ACCOUNT_ID_REMOVED"
    key = "orbit/infra-ecs/terraform.tfstate"
    region = "us-east-1"
    use_lockfile = true
    encrypt = true
  }
}
