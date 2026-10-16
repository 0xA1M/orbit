# alb module - public front door inputs: where to attach, what cert to serve

# the VPC the ALB, target group and SG all live in
variable "vpc_id" {
  type        = string
  description = "VPC everything in this module attaches to"
}

# both public subnets, one per AZ; an ALB refuses fewer than two AZs
variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs the ALB attaches to, one per AZ"
}

# the ISSUED cert from the acm module, passed through root
variable "certificate_arn" {
  type        = string
  description = "ARN of the ACM cert served on the 443 listener"
}

# prepended to every Name tag
variable "name_prefix" {
  type        = string
  description = "Prefix for every Name tag in this module"
}

# frontend today; a variable so a second target group never needs a fork
variable "target_port" {
  type        = number
  description = "Port the target group forwards to on the tasks"
  default     = 8080
}

# cheap dedicated probe, not the full homepage render
variable "health_path" {
  type        = string
  description = "HTTP path the target group health check polls"
  default     = "/_healthz"
}
