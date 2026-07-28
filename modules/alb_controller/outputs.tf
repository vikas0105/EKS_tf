output "irsa_role_arn" {
  value = aws_iam_role.alb_controller.arn
}

output "helm_release_status" {
  value = helm_release.alb_controller.status
}
