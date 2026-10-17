# acm module - single-hostname TLS cert for the shop front door

# one cert for the site hostname only, no apex, no wildcard. the validation
# CNAME now lives in this same config, so the waiter below has something to
# wait on: it blocks until ACM sees the record, then the cert issues in-apply
resource "aws_acm_certificate" "infra_ecs_cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = {
    Name = "${var.name_prefix}-domain-cert"
  }

  # replacement cert must exist before the old one is destroyed, otherwise
  # an attached ALB listener would briefly have no cert
  lifecycle {
    create_before_destroy = true
  }
}

# the ACM validation CNAME, created in Cloudflare where the zone lives.
# unproxied on purpose: a proxied record answers with edge IPs and ACM
# never sees the token, so the cert would sit PENDING forever
resource "cloudflare_dns_record" "validation" {
  for_each = { for dvo in aws_acm_certificate.infra_ecs_cert.domain_validation_options : dvo.domain_name => dvo }

  zone_id = var.cloudflare_zone_id
  name    = trimsuffix(each.value.resource_record_name, ".")
  type    = each.value.resource_record_type
  content = trimsuffix(each.value.resource_record_value, ".")
  proxied = false
  ttl     = 60
}

# the waiter, now correct: it blocks on records this config creates,
# so the cert reaches ISSUED inside the same apply
resource "aws_acm_certificate_validation" "infra_ecs_cert" {
  certificate_arn         = aws_acm_certificate.infra_ecs_cert.arn
  validation_record_fqdns = [for dvo in aws_acm_certificate.infra_ecs_cert.domain_validation_options : trimsuffix(dvo.resource_record_name, ".")]
}
