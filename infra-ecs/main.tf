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
