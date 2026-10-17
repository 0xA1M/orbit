# pin the minimum OpenTofu core + provider versions so applies are reproducible
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.67"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.28"
    }
  }

  # refuse older cores that lack native S3 locking (use_lockfile)
  required_version = "~> 1.12"

  # S3 backend to manage and store state
  # the bucket name is deliberately NOT here; it is passed at init time from backend.tfvars
  backend "s3" {
    key          = "orbit/infra-ecs/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
