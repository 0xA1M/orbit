# network module - VPC, 2 AZ, 1 public + 1 private subnet per AZ, IGW, 2 NAT (one per AZ), route tables

# the whole addressing space for this stack; /16 gives room for ~256 subnets
variable "vpc_cidr" {
  type        = string
  description = "The CIDR block to assign to the VPC"
  default     = "10.0.0.0/16"
}

# prepended to every resource Name tag, e.g. orbit-ecs-vpc
variable "name_prefix" {
  type        = string
  description = "Prefix for every Name tag in this module"
}
