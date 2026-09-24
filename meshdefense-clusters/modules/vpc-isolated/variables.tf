variable "environment" {
  type        = string
  description = "Environment name (e.g. poc, dev, test, stg, prod)"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.100.0.0/16"
  description = "CIDR block for the isolated VPC"
}

variable "az_count" {
  type        = number
  default     = 2
  description = "Number of Availability Zones to spread subnets across (2 for cost-effective POC, 3 for production multi-AZ)"
}

variable "cluster_name" {
  type        = string
  default     = "meshdefense-cluster"
  description = "Name of the Kubernetes cluster to tag subnets for"
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "KMS Key ARN for encrypting CloudWatch VPC Flow Logs"
}

variable "flow_log_retention_days" {
  type        = number
  default     = 30
  description = "CloudWatch log retention in days for VPC Flow Logs"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags"
}
