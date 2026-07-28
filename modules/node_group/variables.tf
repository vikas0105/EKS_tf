variable "cluster_name" {
  type = string
}

variable "node_role_name" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "instance_type" {
  type = string
}

variable "capacity_type" {
  type    = string
  default = "ON_DEMAND"
}

variable "ami_type" {
  type    = string
  default = "AL2023_x86_64_STANDARD"
}

variable "desired_size" {
  type = number
}

variable "min_size" {
  type = number
}

variable "max_size" {
  type = number
}

variable "cluster_version" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
