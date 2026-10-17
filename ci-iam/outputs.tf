# this ARN goes into the repo secret AWS_ROLE_ARN; never hardcode it in yaml
output "role_arn" {
  description = "ARN of the CI role for the GitHub AWS_ROLE_ARN secret"
  value       = aws_iam_role.orbit_ci_role.arn
}
