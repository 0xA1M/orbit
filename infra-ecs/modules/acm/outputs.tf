# consumed by modules/alb when it attaches this cert to the 443 listener
output "certificate_arn" {
  description = "ARN of the ACM certificate for the site hostname"
  value       = aws_acm_certificate.infra_ecs_cert.arn
}

# read with `tofu output`, then create these as CNAME records in Cloudflare by hand
output "domain_validation" {
  description = "DNS validation records to create manually in Cloudflare so ACM can issue the cert"
  value       = aws_acm_certificate.infra_ecs_cert.domain_validation_options
}
