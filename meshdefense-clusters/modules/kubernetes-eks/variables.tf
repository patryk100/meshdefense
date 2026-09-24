variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, test, stg, prod, poc-minimal)"
}

variable "kubernetes_version" {
  type        = string
  default     = "1.33"
  description = "Kubernetes version for EKS control plane (standard support version)"
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
  default     = "AL2023_x86_64_STANDARD"
  description = "AMI Type for workers (AL2023_x86_64_STANDARD or BOTTLEROCKET_x86_64 for DISA STIG / DoD compliance)"
}

variable "system_node_instance_types" {
  type        = list(string)
  default     = ["t3.xlarge"]
  description = "Instance types for system nodes (Core Big Bang, Istio, Gatekeeper, Flux)"
}

variable "system_node_desired_size" {
  type        = number
  default     = 1
  description = "Desired number of system bootstrap nodes"
}

variable "system_node_min_size" {
  type        = number
  default     = 1
  description = "Minimum number of system nodes"
}

variable "system_node_max_size" {
  type        = number
  default     = 2
  description = "Maximum number of system nodes"
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "Customer Managed Key (CMK) ARN for EKS Secrets envelope encryption"
}

variable "ebs_kms_key_arn" {
  type        = string
  description = "Customer Managed Key (CMK) ARN for worker node EBS volume encryption"
}

variable "cluster_log_retention_days" {
  type        = number
  default     = 90
  description = "Retention period for EKS control plane CloudWatch audit logs"
}

variable "enable_karpenter" {
  type        = bool
  default     = true
  description = "Provision Karpenter controller IRSA role, node role, SQS interruption queue, and launch templates"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags"
}
