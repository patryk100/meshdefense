variable "cluster_name" {
  type        = string
  description = "Name of the AKS cluster"
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, test, stg, prod)"
}

variable "location" {
  type        = string
  default     = "usgovvirginia"
  description = "Azure Government region"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for the AKS cluster"
}

variable "kubernetes_version" {
  type        = string
  default     = "1.29"
  description = "Kubernetes version"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID within the isolated VNet"
}

variable "system_vm_size" {
  type        = string
  default     = "Standard_D8s_v5"
  description = "VM size for system nodes"
}

variable "system_node_count" {
  type        = number
  default     = 3
}

variable "system_min_count" {
  type        = number
  default     = 3
}

variable "system_max_count" {
  type        = number
  default     = 6
}

variable "workload_vm_size" {
  type        = string
  default     = "Standard_D16s_v5"
  description = "VM size for workload nodes"
}

variable "workload_node_count" {
  type        = number
  default     = 3
}

variable "workload_min_count" {
  type        = number
  default     = 2
}

variable "workload_max_count" {
  type        = number
  default     = 10
}

variable "tags" {
  type        = map(string)
  default     = {}
}
