provider "aws" {
  region = var.region
}

module "network" {
  source = "./modules/network"
}

module "ecr" {
  source = "./modules/ecr"
}

module "acm" {
  source      = "./modules/acm"
  domain_name = var.domain_name
}

module "alb" {
  source            = "./modules/alb"
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  certificate_arn   = module.acm.certificate_arn
}
