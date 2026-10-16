# prefix for the certificate Name tag, e.g. orbit-domain-cert
variable "name_prefix" {
  type        = string
  description = "Prefix for the certificate Name tag in this module"
}

# the hostname the cert is issued for; fed from gitignored tfvars so the real
# domain never appears in a tracked file
variable "domain_name" {
  type        = string
  description = "Hostname the certificate is issued for"
}
