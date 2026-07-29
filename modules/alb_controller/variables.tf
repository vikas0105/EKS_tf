variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the OIDC provider"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the cluster resides"
  type        = string
  default     = ""
}

variable "alb_controller_replicas" {
  description = "Number of ALB controller replicas"
  type        = number
  default     = 2
}

variable "alb_controller_chart_version" {
  description = "Helm chart version for ALB controller. Leave as null to always install the latest available chart version (recommended - avoids this pin going stale over time). Set to a specific version string (e.g. \"3.4.0\") only if you need to pin for compatibility reasons."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
