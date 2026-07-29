variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the cluster"
  type        = list(string)
}

variable "control_plane_subnet_ids" {
  description = "List of subnet IDs for the control plane (can be same as subnet_ids)"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for the cluster"
  type        = list(string)
}

variable "cluster_enabled_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
  default     = ""
}

variable "enable_public_access" {
  description = "Whether the EKS API endpoint is also reachable publicly (restricted by public_access_cidrs). Default false = private-only, per assignment spec. Set true temporarily to run terraform/kubectl/helm from outside the VPC (e.g. plain CloudShell)."
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public endpoint when enable_public_access is true. Always scope this to your own IP (e.g. [\"1.2.3.4/32\"]) — never leave it as 0.0.0.0/0."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
