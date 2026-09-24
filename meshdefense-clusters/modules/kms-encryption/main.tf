terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.name

  # Base administrative policy statements common to all CMKs
  base_statements = [
    # 1. Root administrative delegation (avoids lockout)
    {
      Sid    = "EnableRootAdminManagement"
      Effect = "Allow"
      Principal = {
        AWS = "arn:${local.partition}:iam::${local.account_id}:root"
      }
      Action   = "kms:*"
      Resource = "*"
    },
    # 2. Key Administrator Access
    {
      Sid    = "AllowKeyAdministrators"
      Effect = "Allow"
      Principal = {
        AWS = var.admin_principals != null && length(var.admin_principals) > 0 ? var.admin_principals : [
          "arn:${local.partition}:iam::${local.account_id}:root"
        ]
      }
      Action = [
        "kms:Create*",
        "kms:Describe*",
        "kms:Enable*",
        "kms:List*",
        "kms:Put*",
        "kms:Update*",
        "kms:Revoke*",
        "kms:Disable*",
        "kms:Get*",
        "kms:Delete*",
        "kms:TagResource",
        "kms:UntagResource",
        "kms:ScheduleKeyDeletion",
        "kms:CancelKeyDeletion"
      ]
      Resource = "*"
    }
  ]

  # CloudWatch logs service statement (if enabled)
  cloudwatch_statement = var.service_type == "cloudwatch" ? [
    {
      Sid    = "AllowCloudWatchLogs"
      Effect = "Allow"
      Principal = {
        Service = "logs.${local.region}.amazonaws.com"
      }
      Action = [
        "kms:Encrypt*",
        "kms:Decrypt*",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:Describe*"
      ]
      Resource = "*"
      Condition = {
        ArnLike = {
          "kms:EncryptionContext:aws:logs:arn" = "arn:${local.partition}:logs:${local.region}:${local.account_id}:*"
        }
      }
    }
  ] : []

  # S3 service statement (if service_type == s3)
  s3_statement = var.service_type == "s3" ? [
    {
      Sid    = "AllowS3Encryption"
      Effect = "Allow"
      Principal = {
        Service = "s3.amazonaws.com"
      }
      Action = [
        "kms:Encrypt*",
        "kms:Decrypt*",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      Resource = "*"
    }
  ] : []

  # EBS / EC2 service statements (allows EC2 and AutoScaling service-linked roles + grants)
  ebs_statement_direct = var.service_type == "ebs" ? [
    {
      Sid    = "AllowDirectAccessToKeyForEBS"
      Effect = "Allow"
      Principal = {
        AWS = "arn:${local.partition}:iam::${local.account_id}:root"
      }
      Action = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      Resource = "*"
    }
  ] : []

  ebs_statement_grants = var.service_type == "ebs" ? [
    {
      Sid    = "AllowAttachmentOfPersistentResources"
      Effect = "Allow"
      Principal = {
        AWS = "arn:${local.partition}:iam::${local.account_id}:root"
      }
      Action = [
        "kms:CreateGrant",
        "kms:ListGrants",
        "kms:RevokeGrant"
      ]
      Resource = "*"
      Condition = {
        Bool = {
          "kms:GrantIsForAWSResource" = "true"
        }
      }
    }
  ] : []


  # RDS service statement (if service_type == rds)
  rds_statement = var.service_type == "rds" ? [
    {
      Sid    = "AllowRDSEncryption"
      Effect = "Allow"
      Principal = {
        Service = "rds.amazonaws.com"
      }
      Action = [
        "kms:Encrypt*",
        "kms:Decrypt*",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:CreateGrant",
        "kms:DescribeKey"
      ]
      Resource = "*"
    }
  ] : []

  # Secrets Manager statement (if service_type == secrets)
  secrets_statement = var.service_type == "secrets" ? [
    {
      Sid    = "AllowSecretsManager"
      Effect = "Allow"
      Principal = {
        Service = "secretsmanager.amazonaws.com"
      }
      Action = [
        "kms:Encrypt*",
        "kms:Decrypt*",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      Resource = "*"
    }
  ] : []

  # Generic cryptographic access for authorized roles/principals
  workload_statement = length(var.key_users) > 0 ? [
    {
      Sid    = "AllowWorkloadKeyUse"
      Effect = "Allow"
      Principal = {
        AWS = var.key_users
      }
      Action = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      Resource = "*"
    }
  ] : []

  all_statements = concat(
    local.base_statements,
    local.cloudwatch_statement,
    local.s3_statement,
    local.ebs_statement_direct,
    local.ebs_statement_grants,
    local.rds_statement,
    local.secrets_statement,
    local.workload_statement
  )

}

# --------------------------------------------------------------------------------------------------
# Customer Managed Key (CMK) with Automated Annual Rotation - NIST 800-53 SC-12/SC-13
# --------------------------------------------------------------------------------------------------
resource "aws_kms_key" "this" {
  description             = var.description
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.all_statements
  })

  tags = merge(var.tags, {
    Name        = var.alias_name
    Compliance  = "NIST-800-53-SC-12_SC-13"
    KeyRotation = "Automated-Annual"
    ServiceType = var.service_type
  })

}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.alias_name}"
  target_key_id = aws_kms_key.this.key_id
}
