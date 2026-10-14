provider "aws" {
  region = var.region
}

module "network" {
  source = "./modules/network"
}

module "ecr" {
  source = "./modules/ecr"
}
