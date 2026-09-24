variable "alias_name" {
  type        = string
  description = "KMS Key Alias name without 'alias/' prefix"
}

variable "description" {
  type        = string
  default     = "MeshDefense Customer Managed Encryption Key with Automated Rotation"
  description = "Description for the KMS key"
}

variable "service_type" {
  type        = string
  default     = "general"
  description = "Target service type: 'general', 'cloudwatch', 's3', 'ebs', 'rds', 'secrets'"
}

variable "deletion_window_in_days" {
  type        = number
  default     = 30
  description = "Waiting period in days before key deletion (7 to 30)"
}

variable "admin_principals" {
  type        = list(string)
  default     = []
  description = "List of IAM ARNs with administrative rights to manage the key"
}

variable "key_users" {
  type        = list(string)
  default     = []
  description = "List of IAM ARNs permitted to use the key for cryptographic operations"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags"
}
