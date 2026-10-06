# what other modules (alb, ecs-service) consume from this one

# the 2 AZ names we actually used
output "azs" {
  description = "The names of the 2 AZs in use"
  value       = slice(data.aws_availability_zones.available.names, 0, 2)
}

# passed to every other module as the parent network
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.infra_ecs_vpc.id
}

# IAM policies that reference the VPC itself
output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = aws_vpc.infra_ecs_vpc.arn
}

# ALB needs these two (public facing)
output "public_subnet_ids" {
  description = "The IDs of the public subnets"
  value       = aws_subnet.infra_ecs_pub_subnet[*].id
}

# every ecs-service module consumes these (task placement)
output "private_subnet_ids" {
  description = "The IDs of the private subnets"
  value       = aws_subnet.infra_ecs_prv_subnet[*].id
}


output "nat_ip" {
  description = "The public IP addresses of the NAT gateways"
  value       = aws_nat_gateway.infra_ecs_nat_gw[*].public_ip
}
