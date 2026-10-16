provider "aws" {
  region = var.region

  # every resource in this root carries these tags unless overridden locally
  default_tags {
    tags = var.tags
  }
}

module "network" {
  source      = "./modules/network"
  name_prefix = var.name_prefix
}

module "ecr" {
  source       = "./modules/ecr"
  name_prefix  = var.name_prefix
  service_list = var.service_list
}

module "acm" {
  source      = "./modules/acm"
  name_prefix = var.name_prefix
  domain_name = var.domain_name
}

module "alb" {
  source            = "./modules/alb"
  name_prefix       = var.name_prefix
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  certificate_arn   = module.acm.certificate_arn
}

resource "aws_service_discovery_http_namespace" "infra_ecs_svc_ns" {
  name        = "${var.name_prefix}.local"
  description = "ECS services namespace used for HTTP discovery"
}

resource "aws_ecs_cluster" "infra_ecs_cluster" {
  name = "${var.name_prefix}-ecs-cluster"

  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.infra_ecs_svc_ns.arn
  }
}

# one instance per shop service; caller sg ids come from sibling instances,
# which stays legal because the call graph has no two-way edges
module "ecs_service" {
  source   = "./modules/ecs-service"
  for_each = local.services

  service_name   = each.key
  image          = "${module.ecr.repo_url[each.key]}:${var.image_tag}"
  container_port = each.value.port
  port_name      = each.value.port_name
  app_protocol   = each.value.port_name == "http" ? "http" : "grpc"
  environment    = each.value.environment
  cpu            = each.value.cpu
  memory         = each.value.memory

  private_subnet_ids = module.network.private_subnet_ids
  cluster_arn        = aws_ecs_cluster.infra_ecs_cluster.arn
  namespace_arn      = aws_service_discovery_http_namespace.infra_ecs_svc_ns.arn
  security_group_id  = aws_security_group.services_sg[each.key].id
  region             = var.region
  name_prefix        = var.name_prefix

  # frontend registers with the ALB, everyone else renders no load balancer
  alb_target_group_arn = each.value.attach_alb ? module.alb.target_group_arn : null
}
