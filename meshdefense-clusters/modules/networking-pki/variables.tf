variable "environment" {
  type        = string
  description = "Environment name"
}

variable "region" {
  type        = string
  default     = "us-gov-west-1"
  description = "Cloud region"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for interface endpoints"
}

variable "route_table_ids" {
  type        = list(string)
  description = "Route table IDs for S3 gateway endpoint"
}

variable "internal_domain" {
  type        = string
  default     = "il6.meshdefense.internal"
  description = "Private DNS domain name"
}

variable "enable_ingress_dns_alias" {
  type        = bool
  default     = false
  description = "Whether to create wildcard and root DNS alias records pointing to the ingress NLB"
}

variable "ingress_nlb_dns_name" {
  type        = string
  default     = null
  description = "DNS name of the internal Network Load Balancer (NLB) for ingress"
}

variable "ingress_nlb_zone_id" {
  type        = string
  default     = null
  description = "Canonical Hosted Zone ID of the internal Network Load Balancer (NLB)"
}

variable "tags" {
  type    = map(string)
  default = {}
}
