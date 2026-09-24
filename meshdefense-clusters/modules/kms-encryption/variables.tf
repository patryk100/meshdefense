variable "alias_name" {
  type        = string
  description = "KMS Key Alias name without 'alias/' prefix"
}

variable "description" {
  type        = string
  default     = "MeshDefense Customer Managed Encryption Key with Automated Rotation"
  description = "Description for the KMS key"
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

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags"
}
