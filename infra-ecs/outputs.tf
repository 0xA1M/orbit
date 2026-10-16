# the ALB listener terminates TLS with this cert
output "certificate_arn" {
  description = "ARN of the ACM certificate for the site hostname"
  value       = module.acm.certificate_arn
}

# read with `tofu output`, then create as a CNAME in Cloudflare by hand
output "domain_validation" {
  description = "DNS validation record to create manually in Cloudflare so ACM can issue the cert"
  value       = module.acm.domain_validation
}
