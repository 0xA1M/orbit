# one security group per service, one ingress rule per caller edge.
# caller edges read from the services locals; the ALB edge for the frontend
# is separate because its source is the alb module sg, not another task sg

# sg per service: ingress only on the service port, only from callers
resource "aws_security_group" "services_sg" {
  for_each = local.services

  name        = "${var.name_prefix}-${each.key}-sg"
  description = "Ingress on the service port from caller SGs only"
  vpc_id      = module.network.vpc_id

  tags = {
    Name = "${var.name_prefix}-${each.key}-sg"
  }
}

# the frontend edge: ALB sg is the only source allowed to reach port 8080
resource "aws_vpc_security_group_ingress_rule" "frontend_from_alb" {
  security_group_id            = aws_security_group.services_sg["frontend"].id
  referenced_security_group_id = module.alb.security_group_id
  from_port                    = 8080
  ip_protocol                  = "tcp"
  to_port                      = 8080
}

# one rule per caller edge; the keys come from names only, so for_each is
# known at plan time, while the sg ids resolve inside the rule body
resource "aws_vpc_security_group_ingress_rule" "caller_ingress" {
  for_each = local.caller_edges

  security_group_id            = aws_security_group.services_sg[each.value.callee].id
  referenced_security_group_id = aws_security_group.services_sg[each.value.caller].id

  from_port   = each.value.port
  ip_protocol = "tcp"
  to_port     = each.value.port
}

# tasks pull images and write logs outbound, so all egress per service
resource "aws_vpc_security_group_egress_rule" "services_egress" {
  for_each = aws_security_group.services_sg

  security_group_id = each.value.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}
