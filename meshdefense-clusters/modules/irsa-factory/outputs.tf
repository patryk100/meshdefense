output "external_secrets_role_arn" {
  description = "IAM Role ARN for External Secrets Operator IRSA"
  value       = try(aws_iam_role.external_secrets[0].arn, null)
}

output "velero_role_arn" {
  description = "IAM Role ARN for Velero Backup & DR IRSA"
  value       = try(aws_iam_role.velero[0].arn, null)
}

output "logging_role_arn" {
  description = "IAM Role ARN for Logging Shipper (Vector/Fluent-bit) IRSA"
  value       = try(aws_iam_role.logging[0].arn, null)
}

output "vault_role_arn" {
  description = "IAM Role ARN for HashiCorp Vault KMS auto-unseal IRSA"
  value       = try(aws_iam_role.vault[0].arn, null)
}

output "ebs_csi_role_arn" {
  description = "IAM Role ARN for AWS EBS CSI driver controller IRSA"
  value       = try(aws_iam_role.ebs_csi[0].arn, null)
}

output "flux_role_arn" {
  description = "IAM Role ARN for Flux v2 GitOps controllers IRSA"
  value       = try(aws_iam_role.flux[0].arn, null)
}

output "custom_role_arns" {
  description = "Map of custom IRSA role names to their IAM Role ARNs"
  value = {
    for k, v in aws_iam_role.custom : k => v.arn
  }
}

output "role_arns" {
  description = "Consolidated map of all created IRSA role ARNs"
  value = merge(
    var.enable_external_secrets ? { external_secrets = aws_iam_role.external_secrets[0].arn } : {},
    var.enable_velero ? { velero = aws_iam_role.velero[0].arn } : {},
    var.enable_logging ? { logging = aws_iam_role.logging[0].arn } : {},
    var.enable_vault ? { vault = aws_iam_role.vault[0].arn } : {},
    var.enable_ebs_csi ? { ebs_csi = aws_iam_role.ebs_csi[0].arn } : {},
    var.enable_flux ? { flux = aws_iam_role.flux[0].arn } : {},
    { for k, v in aws_iam_role.custom : k => v.arn }
  )
}

output "service_account_annotations" {
  description = "Map of Kubernetes ServiceAccount annotations ('eks.amazonaws.com/role-arn') ready for Helm or K8s manifests"
  value = merge(
    var.enable_external_secrets ? {
      "${var.external_secrets_namespace}/${var.external_secrets_service_account}" = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.external_secrets[0].arn
      }
    } : {},
    var.enable_velero ? {
      "${var.velero_namespace}/${var.velero_service_account}" = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.velero[0].arn
      }
    } : {},
    var.enable_logging ? {
      "${var.logging_namespace}/${var.logging_service_account}" = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.logging[0].arn
      }
    } : {},
    var.enable_vault ? {
      "${var.vault_namespace}/${var.vault_service_account}" = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.vault[0].arn
      }
    } : {},
    var.enable_ebs_csi ? {
      "${var.ebs_csi_namespace}/${var.ebs_csi_service_account}" = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.ebs_csi[0].arn
      }
    } : {},
    var.enable_flux ? {
      for sa in var.flux_service_accounts :
      "${var.flux_namespace}/${sa}" => {
        "eks.amazonaws.com/role-arn" = aws_iam_role.flux[0].arn
      }
    } : {},
    {
      for k, v in var.custom_roles :
      "${v.namespace}/${v.service_account}" => {
        "eks.amazonaws.com/role-arn" = aws_iam_role.custom[k].arn
      }
    }
  )
}
