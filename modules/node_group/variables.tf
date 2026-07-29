variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "EKS cluster version"
  type        = string
}

variable "node_group_name" {
  description = "Name of the node group"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for nodes"
  type        = string
  default     = "t3.medium"
}

variable "capacity_type" {
  description = "Type of capacity - ON_DEMAND or SPOT"
  type        = string
  default     = "ON_DEMAND"
}

variable "ami_type" {
  description = "AMI type for worker nodes. Assignment requires Amazon Linux 2023 (AL2023)."
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 3
}

variable "subnet_ids" {
  description = "List of subnet IDs for nodes"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
