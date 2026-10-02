variable "environment" {
  description = "Deployment environment name (e.g., dev, staging, prod, poc-minimal)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster OIDC identity provider"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the EKS cluster OIDC identity provider"
  type        = string
}

variable "permissions_boundary_arn" {
  description = "Optional IAM permissions boundary ARN to enforce on all IRSA roles"
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags to attach to all IRSA resources"
  type        = map(string)
  default     = {}
}

# --------------------------------------------------------------------------------------------------
# 1. External Secrets Operator (ESO)
# --------------------------------------------------------------------------------------------------
variable "enable_external_secrets" {
  description = "Whether to provision the IRSA role for External Secrets Operator"
  type        = bool
  default     = true
}

variable "external_secrets_namespace" {
  description = "Kubernetes namespace where External Secrets Operator runs"
  type        = string
  default     = "external-secrets"
}

variable "external_secrets_service_account" {
  description = "Kubernetes service account name for External Secrets Operator"
  type        = string
  default     = "external-secrets"
}

variable "external_secrets_secret_arns" {
  description = "List of AWS Secrets Manager secret ARNs that External Secrets Operator is permitted to read"
  type        = list(string)
  default     = ["*"]
}

variable "external_secrets_kms_key_arns" {
  description = "List of KMS Key ARNs used to encrypt secrets accessed by External Secrets Operator"
  type        = list(string)
  default     = []
}

# --------------------------------------------------------------------------------------------------
# 2. Velero (Cluster Backup & Disaster Recovery)
# --------------------------------------------------------------------------------------------------
variable "enable_velero" {
  description = "Whether to provision the IRSA role for Velero"
  type        = bool
  default     = true
}

variable "velero_namespace" {
  description = "Kubernetes namespace where Velero runs"
  type        = string
  default     = "velero"
}

variable "velero_service_account" {
  description = "Kubernetes service account name for Velero"
  type        = string
  default     = "velero"
}

variable "velero_bucket_arn" {
  description = "S3 bucket ARN for Velero cluster backups"
  type        = string
  default     = ""
}

variable "velero_kms_key_arn" {
  description = "KMS Key ARN used to encrypt Velero backup S3 objects"
  type        = string
  default     = ""
}

# --------------------------------------------------------------------------------------------------
# 3. Vector / Fluent-Bit (Distributed Enclave Log Shipper)
# --------------------------------------------------------------------------------------------------
variable "enable_logging" {
  description = "Whether to provision the IRSA role for logging agents (Vector / Fluent-bit)"
  type        = bool
  default     = true
}

variable "logging_namespace" {
  description = "Kubernetes namespace where logging agents run"
  type        = string
  default     = "logging"
}

variable "logging_service_account" {
  description = "Kubernetes service account name for logging agents"
  type        = string
  default     = "vector"
}

variable "logging_log_group_arns" {
  description = "CloudWatch Log Group ARNs that logging agents can write to"
  type        = list(string)
  default     = ["*"]
}

variable "logging_bucket_arn" {
  description = "Optional S3 bucket ARN for cold log retention (e.g., Loki or S3 archive)"
  type        = string
  default     = ""
}

variable "logging_kms_key_arns" {
  description = "KMS Key ARNs for CloudWatch Logs and S3 storage used by logging agents"
  type        = list(string)
  default     = []
}

# --------------------------------------------------------------------------------------------------
# 4. HashiCorp Vault (KMS Auto-Unseal)
# --------------------------------------------------------------------------------------------------
variable "enable_vault" {
  description = "Whether to provision the IRSA role for HashiCorp Vault"
  type        = bool
  default     = true
}

variable "vault_namespace" {
  description = "Kubernetes namespace where HashiCorp Vault runs"
  type        = string
  default     = "vault"
}

variable "vault_service_account" {
  description = "Kubernetes service account name for HashiCorp Vault"
  type        = string
  default     = "vault"
}

variable "vault_kms_key_arn" {
  description = "KMS Key ARN dedicated to HashiCorp Vault envelope auto-unseal"
  type        = string
  default     = ""
}

# --------------------------------------------------------------------------------------------------
# 5. AWS EBS CSI Driver (Storage Provisioning & Encryption)
# --------------------------------------------------------------------------------------------------
variable "enable_ebs_csi" {
  description = "Whether to provision the IRSA role for the AWS EBS CSI driver"
  type        = bool
  default     = true
}

variable "ebs_csi_namespace" {
  description = "Kubernetes namespace where the EBS CSI driver controller runs"
  type        = string
  default     = "kube-system"
}

variable "ebs_csi_service_account" {
  description = "Kubernetes service account name for the EBS CSI driver controller"
  type        = string
  default     = "ebs-csi-controller-sa"
}

variable "ebs_kms_key_arn" {
  description = "KMS Key ARN dedicated to EBS volume encryption"
  type        = string
  default     = ""
}

# --------------------------------------------------------------------------------------------------
# 6. Flux v2 Source & Helm Controllers (Airgap OCI / Git Source IRSA)
# --------------------------------------------------------------------------------------------------
variable "enable_flux" {
  description = "Whether to provision the IRSA role for Flux v2 source & helm controllers"
  type        = bool
  default     = true
}

variable "flux_namespace" {
  description = "Kubernetes namespace where Flux v2 controllers run"
  type        = string
  default     = "flux-system"
}

variable "flux_service_accounts" {
  description = "Kubernetes service account names for Flux v2 controllers that interact with AWS APIs (ECR/S3/KMS)"
  type        = list(string)
  default     = ["source-controller", "helm-controller", "kustomize-controller"]
}

variable "flux_s3_bucket_arns" {
  description = "Optional S3 bucket ARNs that Flux v2 can read source artifacts or charts from"
  type        = list(string)
  default     = []
}

variable "flux_kms_key_arns" {
  description = "Optional KMS Key ARNs for decrypting S3 objects or SOPS encrypted secrets"
  type        = list(string)
  default     = []
}

# --------------------------------------------------------------------------------------------------
# 7. AWS Load Balancer Controller (Story 3.2 - Air-Gapped NLB Provisioning)
# --------------------------------------------------------------------------------------------------
variable "enable_aws_load_balancer_controller" {
  description = "Whether to provision the IRSA role for AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "aws_load_balancer_controller_namespace" {
  description = "Kubernetes namespace where AWS Load Balancer Controller runs"
  type        = string
  default     = "kube-system"
}

variable "aws_load_balancer_controller_service_account" {
  description = "Kubernetes service account name for AWS Load Balancer Controller"
  type        = string
  default     = "aws-load-balancer-controller"
}

# --------------------------------------------------------------------------------------------------
# 8. Extensible Custom IRSA Roles Factory Map
# --------------------------------------------------------------------------------------------------
variable "custom_roles" {
  description = "Map of custom IRSA roles to dynamically provision"
  type = map(object({
    role_name                 = optional(string)
    role_description          = optional(string)
    service_account           = string
    namespace                 = string
    inline_policy_statements = optional(list(any), [])
    managed_policy_arns       = optional(list(string), [])
    max_session_duration      = optional(number, 3600)
    tags                      = optional(map(string), {})
  }))
  default = {}
}
