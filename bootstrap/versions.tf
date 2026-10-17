# pin the minimum OpenTofu core + provider versions so applies are reproducible
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.67"
    }
  }

  # refuse older cores that lack native S3 locking (use_lockfile)
  required_version = "~> 1.12"
}
