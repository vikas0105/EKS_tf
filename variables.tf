variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name - used for naming resources"
  type        = string
  default     = "eks-app"
  
  validation {
    condition     = length(var.project_name) <= 20 && can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must be lowercase, alphanumeric with hyphens, max 20 characters."
  }
}

# ============================================
# VPC Configuration
# ============================================
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }
}

# ============================================
# EKS Cluster Configuration
# ============================================
variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.36"
  
  validation {
    condition     = can(regex("^1\\.(3[0-9]|[4-9][0-9])$", var.cluster_version))
    error_message = "Cluster version must be a valid Kubernetes version (e.g., 1.36)."
  }
}

# ============================================
# Node Group Configuration
# ============================================
variable "instance_type" {
  description = "EC2 instance type for nodes"
  type        = string
  default     = "t3.medium"
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9]*\\.[a-z0-9]+$", var.instance_type))
    error_message = "Instance type must be a valid EC2 instance type."
  }
}

variable "capacity_type" {
  description = "Type of capacity associated with the EKS Node Group. Valid values: ON_DEMAND, SPOT"
  type        = string
  default     = "ON_DEMAND"
  
  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "Capacity type must be either ON_DEMAND or SPOT."
  }
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in the node group"
  type        = number
  default     = 1
  
  validation {
    condition     = var.node_group_min_size >= 1 && var.node_group_min_size <= 100
    error_message = "Minimum size must be between 1 and 100."
  }
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in the node group"
  type        = number
  default     = 1
  
  validation {
    condition     = var.node_group_desired_size >= 1 && var.node_group_desired_size <= 100
    error_message = "Desired size must be between 1 and 100."
  }
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in the node group"
  type        = number
  default     = 1
  
  validation {
    condition     = var.node_group_max_size >= 1 && var.node_group_max_size <= 100
    error_message = "Maximum size must be between 1 and 100."
  }
}

# ============================================
# CloudShell VPC Environment (optional)
# ============================================
variable "cloudshell_sg_id" {
  description = "Security group ID of a CloudShell VPC environment, allowed to reach the private EKS API endpoint on 443. Set this only after creating the SG (see README) — leave null/unset otherwise."
  type        = string
  default     = null
}

# ============================================
# Tags
# ============================================
variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Terraform   = "true"
    ManagedBy   = "Terraform"
  }
}
