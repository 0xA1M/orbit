# ecr module - outputs for tasks and pushes, keyed by service name

# the AWS hostname per service, in the form account.dkr.ecr.region.amazonaws.com/orbit/name
output "repo_url" {
  description = "Repository URL, keyed by service name"
  value       = { for k, v in aws_ecr_repository.infra_ecs_orbit_repo : k => v.repository_url }
}

# ARN used by task definitions or pull policies
output "repo_arn" {
  description = "Repository ARN, keyed by service name"
  value       = { for k, v in aws_ecr_repository.infra_ecs_orbit_repo : k => v.arn }
}