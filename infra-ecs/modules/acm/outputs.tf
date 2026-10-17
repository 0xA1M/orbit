# read by the ALB listener; sourced from the validation so the listener
# implicitly waits for ISSUED instead of attaching a PENDING cert
output "certificate_arn" {
  description = "ARN of the issued ACM certificate"
  value       = aws_acm_certificate_validation.infra_ecs_cert.certificate_arn
}

# the validation record this module manages in Cloudflare
output "domain_validation" {
  description = "DNS validation records managed by this module"
  value       = aws_acm_certificate.infra_ecs_cert.domain_validation_options
}
