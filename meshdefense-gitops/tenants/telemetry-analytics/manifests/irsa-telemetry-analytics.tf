# ==================================================================================================
# MeshDefense Tenant IRSA Terraform Configuration: telemetry-analytics
# Generates scoped AWS IAM Role for Service Account (IRSA) via OIDC Trust (NIST 800-53 AC-3, AC-6)
# ==================================================================================================

locals {
  tenant_telemetry_analytics_irsa_role = {
    "telemetry-analytics" = {
      role_name                 = "meshdefense-poc-minimal-irsa-telemetry-analytics"
      role_description          = "Least-privilege IRSA role for telemetry analytics data ingestion"
      namespace                 = "tenant-telemetry"
      service_account           = "telemetry-analytics-sa"
      managed_policy_arns       = "[]"
      inline_policy_statements = [
    {
        "sid": "AllowS3MetricsStorage",
        "effect": "Allow",
        "actions": [
            "s3:PutObject",
            "s3:GetObject",
            "s3:ListBucket"
        ],
        "resources": [
            "arn:aws:s3:::meshdefense-poc-minimal-*-loki",
            "arn:aws:s3:::meshdefense-poc-minimal-*-loki/*"
        ]
    },
    {
        "sid": "AllowKMSStorageDecrypt",
        "effect": "Allow",
        "actions": [
            "kms:Decrypt",
            "kms:GenerateDataKey"
        ],
        "resources": [
            "arn:aws:kms:us-east-1:123456789012:key/*"
        ]
    }
]
      tags = {
        Tenant     = "telemetry-analytics"
        Namespace  = "tenant-telemetry"
        Component  = "tenant-application"
        Compliance = "NIST-800-53-AC-3_AC-6_SC-12_SC-13"
      }
    }
  }
}
