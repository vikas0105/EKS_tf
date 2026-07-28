output "alb_controller_role_arn" {
  description = "ARN of the ALB controller IAM role"
  value       = aws_iam_role.alb_controller.arn
}

output "alb_controller_role_name" {
  description = "Name of the ALB controller IAM role"
  value       = aws_iam_role.alb_controller.name
}

output "alb_controller_policy_arn" {
  description = "ARN of the ALB controller IAM policy"
  value       = aws_iam_policy.alb_controller.arn
}

output "service_account_name" {
  description = "Kubernetes service account name for ALB controller"
  value       = kubernetes_service_account.alb_controller.metadata[0].name
}

output "namespace" {
  description = "Kubernetes namespace where ALB controller is deployed"
  value       = kubernetes_namespace.alb_controller.metadata[0].name
}

output "helm_release_status" {
  description = "Status of the Helm release"
  value       = helm_release.alb_controller.status
}

output "helm_release_version" {
  description = "Helm chart version deployed"
  value       = helm_release.alb_controller.version
}
