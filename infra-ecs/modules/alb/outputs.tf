# consumed downstream: DNS name for the site record, TG ARN for service registration, SG id for task ingress

# the AWS hostname the site A record will point at
output "dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.infra_ecs_orbit_alb.dns_name
}

# the ECS service registers its tasks into this group
output "target_group_arn" {
  description = "ARN of the frontend target group for ECS service registration"
  value       = aws_lb_target_group.infra_ecs_orbit_alb_tg.arn
}

# task security groups ingress from this id, never from the open internet
output "security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.infra_ecs_orbit_alb_sg.id
}
