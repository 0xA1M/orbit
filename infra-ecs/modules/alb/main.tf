# alb module - public front door: SG, ALB, one target group, 443 + 80 listeners

# edge firewall: 80 + 443 in from anywhere, all out. task SGs ingress from
# this SG id later, so no task is ever directly reachable
resource "aws_security_group" "infra_ecs_orbit_alb_sg" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Allow HTTP/HTTPS inbound traffic and all outbound traffic"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_inbound_http" {
  security_group_id = aws_security_group.infra_ecs_orbit_alb_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_inbound_https" {
  security_group_id = aws_security_group.infra_ecs_orbit_alb_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443
}

resource "aws_vpc_security_group_egress_rule" "allow_all_outbound_traffic" {
  security_group_id = aws_security_group.infra_ecs_orbit_alb_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 0
  ip_protocol = "-1"
  to_port     = 0
}

# internet-facing ALB across both public subnets. deletion protection stays
# off on purpose: this stack is destroyed after every session
resource "aws_lb" "infra_ecs_orbit_alb" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.infra_ecs_orbit_alb_sg.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb"
  })
}

# frontend targets only. ip type because Fargate tasks register by ENI IP,
# not instance id. plain HTTP: TLS already terminated at the 443 listener
resource "aws_lb_target_group" "infra_ecs_orbit_alb_tg" {
  name        = "${var.name_prefix}-alb-tg"
  target_type = "ip"
  vpc_id      = var.vpc_id
  protocol    = "HTTP"
  port        = var.target_port

  # cheap dedicated probe, not the full homepage render
  health_check {
    path                = var.health_path
    protocol            = "HTTP"
    port                = "traffic-port"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# TLS ends here: modern policy only, forwards everything to the frontend
resource "aws_lb_listener" "infra_ecs_orbit_alb_https_listener" {
  load_balancer_arn = aws_lb.infra_ecs_orbit_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.infra_ecs_orbit_alb_tg.arn
  }
}

# plaintext catcher: permanent redirect, original host/path/query preserved
resource "aws_lb_listener" "infra_ecs_orbit_alb_http_listener" {
  load_balancer_arn = aws_lb.infra_ecs_orbit_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
