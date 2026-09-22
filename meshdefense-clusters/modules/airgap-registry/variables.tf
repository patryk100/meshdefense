variable "environment" {
  type        = string
  description = "Environment name (dev, test, stg, prod)"
}

variable "namespace" {
  type        = string
  default     = "harbor"
  description = "Namespace to install Harbor"
}

variable "registry_domain" {
  type        = string
  description = "Internal FQDN for the registry, e.g. registry.il6.meshdefense.internal"
}

variable "harbor_chart_path" {
  type        = string
  default     = "harbor"
  description = "Local path or internal Helm repo chart name for Harbor"
}

variable "harbor_chart_version" {
  type        = string
  default     = "1.14.0"
}

variable "tls_secret_name" {
  type        = string
  default     = "harbor-tls"
  description = "Secret name containing the internal CA-signed TLS certificate"
}

variable "storage_type" {
  type        = string
  default     = "s3"
  description = "Storage backend for images: s3, azure, gcs, or filesystem"
}

variable "storage_bucket" {
  type        = string
  default     = ""
  description = "S3/GCS bucket or Azure container for image storage"
}

variable "storage_region" {
  type        = string
  default     = ""
}
