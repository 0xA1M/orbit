# acm module - single-hostname TLS cert for the shop front door

# one cert for the site hostname only, no apex, no wildcard. DNS-validated
# against a zone outside Route53, so the validation CNAME is created outside
# this config: the cert stays PENDING until that record exists, then ACM
# issues it with nothing further required here
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
