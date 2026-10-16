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
