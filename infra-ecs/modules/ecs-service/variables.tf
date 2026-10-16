# ecs-service module inputs: one instance is one service

# single identity shared by the task family, log group and discovery name
variable "service_name" {
  type        = string
  description = "Service identity used for family, log group and discovery names"
}

# must include the SHA tag; latest-style tags defeat the immutable-tag policy
variable "image" {
  type        = string
  description = "Container image URI including immutable tag"
}

# the port the app actually binds; ALB and callers must agree with this number
variable "container_port" {
  type        = number
  description = "Port the container listens on"
}

# Service Connect routes by this string, not by number; a typo here registers
# successfully and then blackholes traffic with no error anywhere
variable "port_name" {
  type        = string
  description = "Service Connect port name, must equal the container port mapping name"
}

# documented protocol hint on the port mapping; grpc for inter-service calls,
# http for the one port an ALB speaks plain HTTP to
variable "app_protocol" {
  type        = string
  description = "Protocol hint recorded on the port mapping"
  default     = "grpc"
}

# injected as plain strings; secrets do not belong here, use Secrets Manager
variable "environment" {
  type        = map(string)
  description = "Environment variables injected into the container"
  default     = {}
}

# strings, not numbers; only certain cpu/memory pairs are legal in Fargate
variable "cpu" {
  type        = string
  description = "Fargate CPU units for the task"
  default     = "256"
}

variable "memory" {
  type        = string
  description = "Fargate memory for the task"
  default     = "512"
}

# one task is the dev default; more tasks with no target in front just idle
variable "desired_count" {
  type        = number
  description = "Number of tasks to keep running"
  default     = 1
}

# the identity SG, owned at root so the caller graph can wire without cycles
variable "security_group_id" {
  type        = string
  description = "Security group ID attached to the task ENI"
}

# tasks launch here; private IPs only, egress through the NAT route
variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs the tasks launch into"
}

# the service is a child of this cluster; deleting the cluster takes every service with it
variable "cluster_arn" {
  type        = string
  description = "ARN of the ECS cluster"
}

# service names under this namespace resolve inside the VPC without a load balancer
variable "namespace_arn" {
  type        = string
  description = "ARN of the Service Connect namespace"
}

# set only for frontend; backends registering here would steal shop traffic
variable "alb_target_group_arn" {
  type        = string
  description = "Target group ARN for frontend registration, null for backends"
  default     = null
}

# single source of truth, also used by the awslogs region option
variable "region" {
  type        = string
  description = "Region every resource in this module is created in"
}

# no default: root owns the single value and passes it in
variable "name_prefix" {
  type        = string
  description = "Prefix for every Name tag in this module"
}