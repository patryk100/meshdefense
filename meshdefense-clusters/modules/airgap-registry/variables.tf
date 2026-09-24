variable "environment" {
  description = "Target deployment environment name (e.g. dev, test, stg, prod, poc-minimal)"
  type        = string
}

variable "kms_key_arn" {
  description = "Optional Customer Managed KMS Key ARN for ECR repository encryption. Defaults to AWS managed AES-256 if empty."
  type        = string
  default     = null
}

variable "additional_repositories" {
  description = "Additional private ECR repository names to create for application or platform workloads"
  type        = list(string)
  default     = []
}

variable "image_tag_mutability" {
  description = "The tag mutability setting for the repository. Must be one of: MUTABLE or IMMUTABLE"
  type        = string
  default     = "MUTABLE"
}

variable "tags" {
  description = "Tags to attach to all provisioned ECR repositories"
  type        = map(string)
  default     = {}
}
