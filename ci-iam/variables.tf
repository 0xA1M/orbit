# which repo may assume the role; baked into the sub condition of the trust
variable "github_org" {
  type        = string
  description = "GitHub org that owns the repo"
}

variable "github_repo" {
  type        = string
  description = "GitHub repo allowed to assume the CI role"
}

# must not collide with future IRSA roles; keep the orbit- prefix convention
variable "role_name" {
  type        = string
  description = "Name of the CI role GitHub workflows assume"
  default     = "orbit-ci"
}

# state bucket name feeds the S3 ARNs in the tofu policy; same bucket as the rest
variable "state_bucket" {
  type        = string
  description = "S3 bucket holding OpenTofu state"
}

variable "tags" {
  type        = map(string)
  description = "Extra tags applied to every resource created here"
  default     = {}
}
