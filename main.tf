terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # ============================================
  # Remote state (S3 + DynamoDB)
  # ============================================
  # This block is intentionally empty — bucket/key/region/table are
  # supplied at `terraform init` time via -backend-config flags, run
  # automatically by ./bootstrap.sh. This file never needs to be edited
  # or committed again after the initial upload: the same script works
  # identically on this clone, a new CloudShell session, or any machine,
  # because the bucket name is deterministic (derived from your AWS
  # account ID) and bootstrap.sh re-creates/reuses it every time.
  backend "s3" {}
}

# Configure AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Terraform   = "true"
      Environment = var.environment
      Project     = var.project_name
    }
  }
}

# Configure Helm Provider
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

# Configure Kubernetes Provider
# Required by the alb_controller module's kubernetes_service_account resource
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.main.token
}

# Configure kubectl Provider
provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.main.token
  load_config_file       = false
}

# Get cluster auth token
data "aws_eks_cluster_auth" "main" {
  name = module.eks.cluster_name
}

# ============================================
# VPC Module
# ============================================
module "vpc" {
  source = "./modules/vpc"

  aws_region    = var.aws_region
  environment   = var.environment
  project_name  = var.project_name
  vpc_cidr      = var.vpc_cidr

  tags = merge(
    var.tags,
    {
      Module = "vpc"
    }
  )
}

# ============================================
# EKS Cluster Module
# ============================================
module "eks" {
  source = "./modules/eks"

  cluster_name    = "${var.project_name}-${var.environment}"
  cluster_version = var.cluster_version
  vpc_id          = module.vpc.vpc_id

  # Network configuration
  subnet_ids              = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)
  control_plane_subnet_ids = module.vpc.private_subnet_ids

  # Security
  security_group_ids = [module.vpc.vpc_default_security_group_id]

  # Logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = merge(
    var.tags,
    {
      Module = "eks"
    }
  )
}

# ============================================
# Node Group Module
# ============================================
module "node_group" {
  source = "./modules/node_group"

  cluster_name    = module.eks.cluster_name
  cluster_version = var.cluster_version
  
  # Node group configuration
  node_group_name = "${var.project_name}-${var.environment}-nodes"
  instance_type   = var.instance_type
  capacity_type   = var.capacity_type

  # Scaling
  min_size     = var.node_group_min_size
  desired_size = var.node_group_desired_size
  max_size     = var.node_group_max_size

  # Subnets (use private subnets for security)
  subnet_ids = module.vpc.private_subnet_ids

  # Tags
  tags = merge(
    var.tags,
    {
      Module = "node_group"
    }
  )

  depends_on = [module.eks]
}

# ============================================
# ALB Controller Module
# ============================================
module "alb_controller" {
  source = "./modules/alb_controller"

  cluster_name = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  # VPC configuration for ALB to find subnets
  vpc_id = module.vpc.vpc_id

  tags = merge(
    var.tags,
    {
      Module = "alb_controller"
    }
  )

  depends_on = [
    module.eks,
    module.node_group
  ]
}
