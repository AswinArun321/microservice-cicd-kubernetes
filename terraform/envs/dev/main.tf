locals {
  cluster_name = "microservice-eks-${var.environment}"
}

module "network" {
  source = "../../modules/network"

  vpc_cidr               = var.vpc_cidr
  public_subnet_cidrs    = var.public_subnet_cidrs
  availability_zones     = var.availability_zones
  cluster_name           = local.cluster_name
  enable_nat             = var.enable_nat
  enable_private_subnets = false
  environment            = var.environment
}

module "ecr" {
  source = "../../modules/ecr"

  repository_names      = ["auth-service", "api-service", "worker-service"]
  image_tag_mutability  = "IMMUTABLE"
  keep_last_image_count = 10
  environment           = var.environment
}

module "github_oidc" {
  source = "../../modules/github-oidc"

  github_repo                = var.github_repo
  ecr_repository_arns        = values(module.ecr.repository_arns)
  cluster_name               = local.cluster_name
  aws_region                 = var.aws_region
  create_oidc_provider       = var.create_oidc_provider
  existing_oidc_provider_arn = var.existing_oidc_provider_arn
  environment                = var.environment
}

module "eks" {
  source = "../../modules/eks"

  cluster_name        = local.cluster_name
  cluster_version     = var.cluster_version
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.public_subnet_ids
  public_access_cidrs = var.public_access_cidrs
  node_instance_types = var.node_instance_types
  desired_size        = var.desired_node_count
  min_size            = 1
  max_size            = 3
  eks_deploy_role_arn = module.github_oidc.eks_deploy_role_arn
  environment         = var.environment
}
