# what the root reads back, later CI pushes to repo_url and ECS pulls by arn

# list, one URL per repo in for_each order; a keyed map is a small change if CI needs lookup by service
output "repo_url" {
  description = "Repository URL"
  value       = [for r in aws_ecr_repository.infra_ecs_orbit_repo : r.repository_url]
}

# same list shape, one arn per repo
output "repo_arn" {
  description = "Repository ARN"
  value       = [for r in aws_ecr_repository.infra_ecs_orbit_repo : r.arn]
}
