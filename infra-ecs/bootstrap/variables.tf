# where everything lives
variable "region" {
  type        = string
  description = "AWS region for all resources"
  default     = "us-east-1"
}

# globally unique across all of AWS
variable "bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name for OpenTofu state"
}

# feed this to provider default_tags; per-resource tags can override
variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource via provider default_tags"
  default = {
    Project   = "orbit"
    ManagedBy = "opentofu"
    Phase     = "bootstrap"
  }
}
