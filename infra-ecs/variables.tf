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

# single source of truth for naming; passed to every module
variable "name_prefix" {
  type        = string
  description = "Prefix for every Name tag in the stack"
  default     = "orbit"
}

# carried into provider default_tags, so every resource gets them
variable "tags" {
  type        = map(string)
  description = "Extra tags applied to every resource via provider default_tags"
  default     = {}
}

# tag appended to the image uri; note the repo policy lets this one be
# repointed, which trades immutability for deploy convenience
variable "image_tag" {
  type        = string
  description = "Image tag the ECS task definitions pull"
  default     = "latest"
}

# the full service set
variable "service_list" {
  type        = set(string)
  description = "Services that get an ECR repo"
  default     = ["adservice", "cartservice", "checkoutservice", "currencyservice", "emailservice", "frontend", "paymentservice", "productcatalogservice", "recommendationservice", "shippingservice", "loadgenerator"]
}
