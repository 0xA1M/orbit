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

# the dialable name for this service: the short endpoint name the Service
# Connect resolver answers inside tasks (not a VPC DNS record)
output "discovery_name" {
  description = "Endpoint name other services dial for this service"
  value       = var.service_name
}