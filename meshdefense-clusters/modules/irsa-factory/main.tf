# ==================================================================================================
# MeshDefense Granular IRSA Factory & OIDC Trust Architecture (Story 2.3)
# Zero static credentials, strictly scoped IAM Roles for Service Accounts (IRSA)
# Complies with NIST 800-53 AC-3 (Access Enforcement), AC-6 (Least Privilege), SC-12/SC-13 (KMS)
# ==================================================================================================

data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  partition   = data.aws_partition.current.partition
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.name
  oidc_issuer = replace(var.oidc_provider_url, "https://", "")
}

# --------------------------------------------------------------------------------------------------
# Helper: Reusable AssumeRoleWithWebIdentity Trust Policy Template
# --------------------------------------------------------------------------------------------------
# Sub & Aud conditions ensure that only the specified ServiceAccount in the specified Namespace
# can assume the role via AWS STS.
# --------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------
# 1. External Secrets Operator (ESO) IRSA Role
# --------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "external_secrets_assume" {
  count = var.enable_external_secrets ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${var.external_secrets_namespace}:${var.external_secrets_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0

  name                 = "${var.cluster_name}-irsa-external-secrets"
  description          = "Least-privilege IRSA role for External Secrets Operator on ${var.cluster_name}"
  assume_role_policy   = data.aws_iam_policy_document.external_secrets_assume[0].json
  permissions_boundary = var.permissions_boundary_arn

  tags = merge(var.tags, {
    Name           = "${var.cluster_name}-irsa-external-secrets"
    Component      = "external-secrets-operator"
    Namespace      = var.external_secrets_namespace
    ServiceAccount = var.external_secrets_service_account
  })
}

data "aws_iam_policy_document" "external_secrets_policy" {
  count = var.enable_external_secrets ? 1 : 0

  statement {
    sid    = "SecretsManagerReadAccess"
    effect = "Allow"
    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]
    resources = var.external_secrets_secret_arns
  }

  dynamic "statement" {
    for_each = length(var.external_secrets_kms_key_arns) > 0 ? [1] : []
    content {
      sid    = "KMSDecryptAccess"
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:DescribeKey"
      ]
      resources = var.external_secrets_kms_key_arns
    }
  }
}

resource "aws_iam_policy" "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0

  name        = "${var.cluster_name}-irsa-external-secrets-policy"
  description = "Granular least-privilege policy for External Secrets Operator"
  policy      = data.aws_iam_policy_document.external_secrets_policy[0].json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0

  role       = aws_iam_role.external_secrets[0].name
  policy_arn = aws_iam_policy.external_secrets[0].arn
}

# --------------------------------------------------------------------------------------------------
# 2. Velero (Cluster Backup & Disaster Recovery) IRSA Role
# --------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "velero_assume" {
  count = var.enable_velero ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${var.velero_namespace}:${var.velero_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "velero" {
  count = var.enable_velero ? 1 : 0

  name                 = "${var.cluster_name}-irsa-velero"
  description          = "Least-privilege IRSA role for Velero Backup & DR on ${var.cluster_name}"
  assume_role_policy   = data.aws_iam_policy_document.velero_assume[0].json
  permissions_boundary = var.permissions_boundary_arn

  tags = merge(var.tags, {
    Name           = "${var.cluster_name}-irsa-velero"
    Component      = "velero"
    Namespace      = var.velero_namespace
    ServiceAccount = var.velero_service_account
  })
}

data "aws_iam_policy_document" "velero_policy" {
  count = var.enable_velero ? 1 : 0

  statement {
    sid    = "EC2SnapshotManagement"
    effect = "Allow"
    actions = [
      "ec2:DescribeVolumes",
      "ec2:DescribeSnapshots",
      "ec2:CreateSnapshot",
      "ec2:CreateSnapshots",
      "ec2:DeleteSnapshot",
      "ec2:CreateTags"
    ]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = var.velero_bucket_arn != "" ? [1] : []
    content {
      sid    = "S3BackupBucketOperations"
      effect = "Allow"
      actions = [
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ]
      resources = [var.velero_bucket_arn]
    }
  }

  dynamic "statement" {
    for_each = var.velero_bucket_arn != "" ? [1] : []
    content {
      sid    = "S3BackupObjectOperations"
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:AbortMultipartUpload",
        "s3:ListMultipartUploadParts"
      ]
      resources = ["${var.velero_bucket_arn}/*"]
    }
  }

  dynamic "statement" {
    for_each = var.velero_kms_key_arn != "" ? [1] : []
    content {
      sid    = "KMSCryptographicOperations"
      effect = "Allow"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      resources = [var.velero_kms_key_arn]
    }
  }
}

resource "aws_iam_policy" "velero" {
  count = var.enable_velero ? 1 : 0

  name        = "${var.cluster_name}-irsa-velero-policy"
  description = "Granular least-privilege policy for Velero backup/restore"
  policy      = data.aws_iam_policy_document.velero_policy[0].json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "velero" {
  count = var.enable_velero ? 1 : 0

  role       = aws_iam_role.velero[0].name
  policy_arn = aws_iam_policy.velero[0].arn
}

# --------------------------------------------------------------------------------------------------
# 3. Vector / Fluent-Bit (Distributed Logging Shipper) IRSA Role
# --------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "logging_assume" {
  count = var.enable_logging ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${var.logging_namespace}:${var.logging_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "logging" {
  count = var.enable_logging ? 1 : 0

  name                 = "${var.cluster_name}-irsa-logging"
  description          = "Least-privilege IRSA role for cluster logging agent (Vector/Fluent-bit) on ${var.cluster_name}"
  assume_role_policy   = data.aws_iam_policy_document.logging_assume[0].json
  permissions_boundary = var.permissions_boundary_arn

  tags = merge(var.tags, {
    Name           = "${var.cluster_name}-irsa-logging"
    Component      = "logging-agent"
    Namespace      = var.logging_namespace
    ServiceAccount = var.logging_service_account
  })
}

data "aws_iam_policy_document" "logging_policy" {
  count = var.enable_logging ? 1 : 0

  statement {
    sid    = "CloudWatchLogsIngestion"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]
    resources = var.logging_log_group_arns
  }

  dynamic "statement" {
    for_each = var.logging_bucket_arn != "" ? [1] : []
    content {
      sid    = "S3LogArchiveStorage"
      effect = "Allow"
      actions = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ]
      resources = [
        var.logging_bucket_arn,
        "${var.logging_bucket_arn}/*"
      ]
    }
  }

  dynamic "statement" {
    for_each = length(var.logging_kms_key_arns) > 0 ? [1] : []
    content {
      sid    = "KMSLogEncryption"
      effect = "Allow"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      resources = var.logging_kms_key_arns
    }
  }
}

resource "aws_iam_policy" "logging" {
  count = var.enable_logging ? 1 : 0

  name        = "${var.cluster_name}-irsa-logging-policy"
  description = "Granular least-privilege policy for log shipping agents"
  policy      = data.aws_iam_policy_document.logging_policy[0].json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "logging" {
  count = var.enable_logging ? 1 : 0

  role       = aws_iam_role.logging[0].name
  policy_arn = aws_iam_policy.logging[0].arn
}

# --------------------------------------------------------------------------------------------------
# 4. HashiCorp Vault (KMS Auto-Unseal) IRSA Role
# --------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "vault_assume" {
  count = var.enable_vault ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${var.vault_namespace}:${var.vault_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "vault" {
  count = var.enable_vault ? 1 : 0

  name                 = "${var.cluster_name}-irsa-vault"
  description          = "Least-privilege IRSA role for HashiCorp Vault KMS auto-unseal on ${var.cluster_name}"
  assume_role_policy   = data.aws_iam_policy_document.vault_assume[0].json
  permissions_boundary = var.permissions_boundary_arn

  tags = merge(var.tags, {
    Name           = "${var.cluster_name}-irsa-vault"
    Component      = "hashicorp-vault"
    Namespace      = var.vault_namespace
    ServiceAccount = var.vault_service_account
  })
}

data "aws_iam_policy_document" "vault_policy" {
  count = var.enable_vault ? 1 : 0

  statement {
    sid    = "VaultKmsAutoUnseal"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    resources = var.vault_kms_key_arn != "" ? [var.vault_kms_key_arn] : ["*"]
  }
}

resource "aws_iam_policy" "vault" {
  count = var.enable_vault ? 1 : 0

  name        = "${var.cluster_name}-irsa-vault-policy"
  description = "Granular least-privilege policy for HashiCorp Vault KMS auto-unseal"
  policy      = data.aws_iam_policy_document.vault_policy[0].json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "vault" {
  count = var.enable_vault ? 1 : 0

  role       = aws_iam_role.vault[0].name
  policy_arn = aws_iam_policy.vault[0].arn
}

# --------------------------------------------------------------------------------------------------
# 5. AWS EBS CSI Driver (Storage Provisioner & KMS Key Grant Access) IRSA Role
# --------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "ebs_csi_assume" {
  count = var.enable_ebs_csi ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${var.ebs_csi_namespace}:${var.ebs_csi_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  count = var.enable_ebs_csi ? 1 : 0

  name                 = "${var.cluster_name}-irsa-ebs-csi"
  description          = "Least-privilege IRSA role for AWS EBS CSI driver controller on ${var.cluster_name}"
  assume_role_policy   = data.aws_iam_policy_document.ebs_csi_assume[0].json
  permissions_boundary = var.permissions_boundary_arn

  tags = merge(var.tags, {
    Name           = "${var.cluster_name}-irsa-ebs-csi"
    Component      = "aws-ebs-csi-driver"
    Namespace      = var.ebs_csi_namespace
    ServiceAccount = var.ebs_csi_service_account
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_managed" {
  count = var.enable_ebs_csi ? 1 : 0

  role       = aws_iam_role.ebs_csi[0].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Dedicated KMS Encryption permissions for custom EBS CMK
data "aws_iam_policy_document" "ebs_csi_kms" {
  count = var.enable_ebs_csi && var.ebs_kms_key_arn != "" ? 1 : 0

  statement {
    sid    = "EBSKMSKeyAccess"
    effect = "Allow"
    actions = [
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [var.ebs_kms_key_arn]
  }
}

resource "aws_iam_policy" "ebs_csi_kms" {
  count = var.enable_ebs_csi && var.ebs_kms_key_arn != "" ? 1 : 0

  name        = "${var.cluster_name}-irsa-ebs-csi-kms-policy"
  description = "KMS encryption permissions for EBS CSI driver controller"
  policy      = data.aws_iam_policy_document.ebs_csi_kms[0].json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_kms" {
  count = var.enable_ebs_csi && var.ebs_kms_key_arn != "" ? 1 : 0

  role       = aws_iam_role.ebs_csi[0].name
  policy_arn = aws_iam_policy.ebs_csi_kms[0].arn
}

# --------------------------------------------------------------------------------------------------
# 6. Extensible Dynamic Custom IRSA Roles Factory
# --------------------------------------------------------------------------------------------------
resource "aws_iam_role" "custom" {
  for_each = var.custom_roles

  name        = coalesce(each.value.role_name, "${var.cluster_name}-irsa-${each.key}")
  description = coalesce(each.value.role_description, "Dynamic IRSA role for ${each.key} on ${var.cluster_name}")

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${local.oidc_issuer}:sub" = "system:serviceaccount:${each.value.namespace}:${each.value.service_account}"
            "${local.oidc_issuer}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  max_session_duration = each.value.max_session_duration
  permissions_boundary = var.permissions_boundary_arn

  tags = merge(var.tags, each.value.tags, {
    Name           = coalesce(each.value.role_name, "${var.cluster_name}-irsa-${each.key}")
    Namespace      = each.value.namespace
    ServiceAccount = each.value.service_account
  })
}

# Custom Inline Policy for Dynamic Roles
resource "aws_iam_role_policy" "custom_inline" {
  for_each = {
    for k, v in var.custom_roles : k => v
    if length(v.inline_policy_statements) > 0
  }

  name = "${aws_iam_role.custom[each.key].name}-inline-policy"
  role = aws_iam_role.custom[each.key].name

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = each.value.inline_policy_statements
  })
}

# Managed Policy Attachments for Dynamic Roles
locals {
  custom_role_policy_attachments = flatten([
    for role_key, role_val in var.custom_roles : [
      for policy_arn in coalesce(role_val.managed_policy_arns, []) : {
        key        = "${role_key}-${replace(replace(policy_arn, "/", "-"), ":", "-")}"
        role_name  = aws_iam_role.custom[role_key].name
        policy_arn = policy_arn
      }
    ]
  ])
}

resource "aws_iam_role_policy_attachment" "custom_managed" {
  for_each = {
    for item in local.custom_role_policy_attachments : item.key => item
  }

  role       = each.value.role_name
  policy_arn = each.value.policy_arn
}
