# where everything lives
variable "region" {
  type        = string
  description = "AWS region for all resources"
  default     = "us-east-1"
}

# the site hostname, real value in gitignored terraform.tfvars
variable "domain_name" {
  type        = string
  description = "Hostname for the ACM certificate and the ALB"
}
