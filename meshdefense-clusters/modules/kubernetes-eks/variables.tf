variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, test, stg, prod)"
}

variable "kubernetes_version" {
  type        = string
  default     = "1.29"
  description = "Kubernetes version compatible with targeted Big Bang release"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the cluster is deployed"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block of the VPC"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for EKS control plane and worker nodes"
}

variable "ami_type" {
  type        = string
  default     = "BOTTLEROCKET_x86_64"
  description = "AMI Type for workers (BOTTLEROCKET_x86_64 or AL2_x86_64 for DISA STIG compliance)"
}

variable "system_node_instance_types" {
  type        = list(string)
  default     = ["m6i.2xlarge"]
  description = "Instance types for system nodes (Core Big Bang, Istio, Gatekeeper, Flux)"
}

variable "system_node_desired_size" {
  type        = number
  default     = 3
  description = "Desired number of system nodes"
}

variable "system_node_min_size" {
  type        = number
  default     = 3
  description = "Minimum number of system nodes"
}

variable "system_node_max_size" {
  type        = number
  default     = 6
  description = "Maximum number of system nodes"
}

variable "workload_node_instance_types" {
  type        = list(string)
  default     = ["m6i.4xlarge"]
  description = "Instance types for workload nodes (GitLab, SonarQube, Monitoring, apps)"
}

variable "workload_node_desired_size" {
  type        = number
  default     = 3
  description = "Desired number of workload nodes"
}

variable "workload_node_min_size" {
  type        = number
  default     = 2
  description = "Minimum number of workload nodes"
}

variable "workload_node_max_size" {
  type        = number
  default     = 10
  description = "Maximum number of workload nodes"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags"
}
