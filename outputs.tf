output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_endpoint_public_access" {
  value = module.eks.cluster_endpoint_public_access
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "alb_controller_role_arn" {
  value = module.alb_controller.irsa_role_arn
}

output "configure_kubectl" {
  description = "Command to update local kubeconfig (must be run from inside the VPC / over VPN, since the endpoint is private)"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
