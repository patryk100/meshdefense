variable "cluster_name" {
  type        = string
  description = "Name of the GKE cluster"
}

variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, test, stg, prod)"
}

variable "network" {
  type        = string
  description = "VPC network name"
}

variable "subnetwork" {
  type        = string
  description = "Subnetwork name"
}

variable "master_ipv4_cidr_block" {
  type        = string
  default     = "172.16.0.0/28"
  description = "Private CIDR range for GKE control plane nodes"
}

variable "pods_range_name" {
  type        = string
  description = "Secondary IP range name for Pods"
}

variable "services_range_name" {
  type        = string
  description = "Secondary IP range name for Services"
}

variable "kms_key_name" {
  type        = string
  description = "Customer Managed Encryption Key (CMEK) for GKE database encryption"
}

variable "authorized_cidr_blocks" {
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default     = []
  description = "Authorized CIDR blocks allowed to connect to private master endpoint"
}

variable "system_machine_type" {
  type        = string
  default     = "e2-standard-8"
}

variable "system_node_count" {
  type        = number
  default     = 3
}

variable "workload_machine_type" {
  type        = string
  default     = "e2-standard-16"
}

variable "workload_node_count" {
  type        = number
  default     = 3
}

variable "labels" {
  type        = map(string)
  default     = {}
}
