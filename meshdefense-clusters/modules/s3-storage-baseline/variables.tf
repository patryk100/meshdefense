variable "environment" {
  type        = string
  description = "Environment identifier (e.g., poc-minimal, dev, prod)"
}

variable "kms_key_arn" {
  type        = string
  description = "Customer Managed Key (CMK) ARN for S3 server-side encryption"
}

variable "force_destroy" {
  type        = bool
  default     = true
  description = "Whether all objects should be deleted from bucket on destroy (safe for testing/dev)"
}

variable "harbor_retention_days" {
  type        = number
  default     = 90
  description = "Expiration days for non-current Harbor image layers"
}

variable "velero_retention_days" {
  type        = number
  default     = 60
  description = "Expiration days for Velero backup snapshots"
}

variable "loki_retention_days" {
  type        = number
  default     = 90
  description = "Expiration days for Loki log chunks"
}

variable "audit_retention_days" {
  type        = number
  default     = 365
  description = "Expiration days for cluster audit logs (NIST 800-53 AU-11)"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags applied to all S3 buckets"
}
