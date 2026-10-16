# ecs-service module - outputs for root wiring and debugging

# the ARN ECS reports for this running service
output "service_arn" {
  description = "ARN of the ECS service for this shop component"
  value       = aws_ecs_service.infra_ecs_service.id
}

# task definition family:revision the service is pinned to
output "task_definition" {
  description = "Task definition the service is currently tracking"
  value       = aws_ecs_task_definition.infra_ecs_task_def.arn
}

# the FQDN callers actually dial for this service, service_name.orbit.local
output "discovery_fqdn" {
  description = "Fully qualified Service Connect name of this service"
  value       = "${var.service_name}.${var.name_prefix}.local"
}