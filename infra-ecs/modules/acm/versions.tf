# provider sources this module needs; without the cloudflare entry tofu
# assumes the hashicorp namespace and fails to find the provider
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

  required_version = "~> 1.12"
}
