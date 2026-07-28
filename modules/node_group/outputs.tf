output "node_group_id" {
  description = "EKS node group ID"
  value       = aws_eks_node_group.main.id
}

output "node_group_arn" {
  description = "EKS node group ARN"
  value       = aws_eks_node_group.main.arn
}

output "node_group_status" {
  description = "EKS node group status"
  value       = aws_eks_node_group.main.status
}

output "node_group_resources" {
  description = "EKS node group resources"
  value       = aws_eks_node_group.main.resources
}

output "node_role_arn" {
  description = "ARN of the node IAM role"
  value       = aws_iam_role.node.arn
}

output "node_role_name" {
  description = "Name of the node IAM role"
  value       = aws_iam_role.node.name
}
