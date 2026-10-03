variable "region" {
  type        = string
  default     = "us-east-1"
  description = "Target AWS region (e.g. us-east-1 or us-gov-west-1)"
}

variable "environment" {
  type        = string
  default     = "poc-minimal"
  description = "Environment identifier"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.104.0.0/16"
  description = "CIDR block for the isolated VPC"
}

variable "az_count" {
  type        = number
  default     = 2
  description = "Number of Availability Zones for private subnets (2 for minimal, 3 for prod)"
}

variable "enable_eks" {
  type        = bool
  default     = false
  description = "Toggle to deploy EKS cluster on the isolated network"
}

variable "kubernetes_version" {
  type        = string
  default     = "1.33"
  description = "Kubernetes version for EKS control plane (standard support version)"
}

variable "enable_bastion" {
  type        = bool
  default     = true
  description = "Toggle to deploy the Day-0 ephemeral administrative bastion"
}

variable "bastion_instance_type" {
  type        = string
  default     = "t3.small"
  description = "Instance type for the ephemeral administrative bastion"
}

variable "enable_rds" {
  type        = bool
  default     = true
  description = "Toggle to deploy hardened RDS PostgreSQL instance"
}

variable "rds_multi_az" {
  type        = bool
  default     = true
  description = "Enable Multi-AZ deployment for RDS PostgreSQL"
}

variable "enable_ingress_dns_alias" {
  type        = bool
  default     = false
  description = "Enable Route 53 wildcard DNS alias pointing to ingress NLB"
}

variable "ingress_nlb_dns_name" {
  type        = string
  default     = null
  description = "DNS name of internal NLB"
}

variable "ingress_nlb_zone_id" {
  type        = string
  default     = null
  description = "Zone ID of internal NLB"
}

variable "custom_irsa_roles" {
  description = "Optional custom IRSA roles dynamically configured for onboarding tenants"
  type        = any
  default     = {}
}


