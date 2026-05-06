module "vpc" {
  source      = "./modules/vpc"
  environment = var.environment
}

module "eks" {
  source          = "./modules/eks"
  cluster_name    = var.cluster_name
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnet_ids
  environment     = var.environment
}

module "ecr" {
  source      = "./modules/ecr"
  environment = var.environment
}
