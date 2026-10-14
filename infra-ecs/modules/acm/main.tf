# acm module - single-hostname TLS cert for the shop front door

# one cert for the site hostname only, no apex, no wildcard. DNS validated,
# but there is deliberately no aws_acm_certificate_validation resource here:
# the zone lives in Cloudflare, so the validation CNAME gets created by hand
# and a waiter resource would just block apply for up to 75 minutes then fail
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
