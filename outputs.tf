# ============================================
# EKS Cluster Outputs
# ============================================
output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
  sensitive   = false
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "eks_cluster_version" {
  description = "EKS cluster version"
  value       = module.eks.cluster_version
}

output "eks_cluster_ca_certificate" {
  description = "EKS cluster CA certificate (base64 encoded)"
  value       = module.eks.cluster_ca_certificate
  sensitive   = true
}

output "eks_cluster_status" {
  description = "EKS cluster status"
  value       = module.eks.cluster_status
}

# ============================================
# VPC Outputs
# ============================================
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_ips" {
  description = "NAT Gateway Elastic IPs"
  value       = module.vpc.nat_gateway_ips
}

# ============================================
# Node Group Outputs
# ============================================
output "node_group_id" {
  description = "Node group ID"
  value       = module.node_group.node_group_id
}

output "node_group_arn" {
  description = "Node group ARN"
  value       = module.node_group.node_group_arn
}

output "node_group_status" {
  description = "Node group status"
  value       = module.node_group.node_group_status
}

output "node_role_arn" {
  description = "Node IAM role ARN"
  value       = module.node_group.node_role_arn
}

# ============================================
# ALB Controller Outputs
# ============================================
output "alb_controller_role_arn" {
  description = "ALB controller IAM role ARN"
  value       = module.alb_controller.alb_controller_role_arn
}

output "alb_controller_namespace" {
  description = "Kubernetes namespace where ALB controller is deployed"
  value       = module.alb_controller.namespace
}

output "alb_controller_service_account" {
  description = "Kubernetes service account for ALB controller"
  value       = module.alb_controller.service_account_name
}

# ============================================
# OIDC Provider Outputs
# ============================================
output "oidc_provider_arn" {
  description = "ARN of OIDC provider for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "URL of OIDC provider for IRSA"
  value       = module.eks.oidc_provider_url
}

# ============================================
# kubectl Configuration
# ============================================
output "configure_kubectl_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

# ============================================
# Summary Output
# ============================================
output "deployment_summary" {
  description = "Deployment summary"
  value = {
    cluster_name     = module.eks.cluster_name
    region           = var.aws_region
    cluster_version  = var.cluster_version
    environment      = var.environment
    vpc_cidr         = var.vpc_cidr
    node_count       = var.node_group_desired_size
    instance_type    = var.instance_type
    capacity_type    = var.capacity_type
    alb_controller   = "Installed"
  }
}
