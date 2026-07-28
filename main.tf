locals {
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
  azs          = var.azs
  cluster_name = var.cluster_name
  tags         = local.common_tags
}

module "eks" {
  source = "./modules/eks"

  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  # Private cluster: no public subnets are passed to the control plane.
  tags = local.common_tags
}

module "node_group" {
  source = "./modules/node_group"

  cluster_name       = module.eks.cluster_name
  node_role_name     = "${var.cluster_name}-node-role"
  subnet_ids         = module.vpc.private_subnet_ids
  instance_type      = var.node_instance_type
  capacity_type      = "ON_DEMAND"
  ami_type           = "AL2023_x86_64_STANDARD"
  desired_size       = var.node_desired_size
  min_size           = var.node_min_size
  max_size           = var.node_max_size
  cluster_version    = var.cluster_version
  tags               = local.common_tags

  depends_on = [module.eks]
}

module "alb_controller" {
  source = "./modules/alb_controller"

  cluster_name             = module.eks.cluster_name
  oidc_provider_arn        = module.eks.oidc_provider_arn
  oidc_provider_url        = module.eks.oidc_provider_url
  vpc_id                   = module.vpc.vpc_id
  aws_region               = var.aws_region
  tags                     = local.common_tags

  depends_on = [module.node_group]
}
