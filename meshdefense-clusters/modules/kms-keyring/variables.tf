variable "environment" {
  type        = string
  description = "Deployment environment name (e.g., poc-minimal, dev, prod)"
}

variable "deletion_window_in_days" {
  type        = number
  default     = 30
  description = "Waiting period in days before key deletion (7 to 30)"
}

variable "admin_principals" {
  type        = list(string)
  default     = []
  description = "List of IAM ARNs with administrative rights across all keyring CMKs"
}

variable "k8s_secrets_key_users" {
  type        = list(string)
  default     = []
  description = "IAM ARNs allowed to use the Kubernetes Secrets encryption key"
}

variable "ebs_key_users" {
  type        = list(string)
  default     = []
  description = "IAM ARNs allowed to use the EBS encryption key"
}

variable "s3_key_users" {
  type        = list(string)
  default     = []
  description = "IAM ARNs allowed to use the S3 encryption key"
}

variable "rds_key_users" {
  type        = list(string)
  default     = []
  description = "IAM ARNs allowed to use the RDS encryption key"
}

variable "secrets_key_users" {
  type        = list(string)
  default     = []
  description = "IAM ARNs allowed to use the Secrets Manager encryption key"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags applied to all keys in the keyring"
}
