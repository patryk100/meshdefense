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

variable "tags" {
  type        = map(string)
  default     = {}
}
