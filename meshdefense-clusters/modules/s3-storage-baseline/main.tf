terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

data "aws_partition" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  bucket_configs = {
    harbor = {
      name_prefix    = "harbor-blobs"
      description    = "Harbor OCI Registry Artifact and Container Blobs"
      purpose        = "Container-Registry"
      retention_days = var.harbor_retention_days
    },
    velero = {
      name_prefix    = "velero-backups"
      description    = "Velero Kubernetes Cluster State and Persistent Volume Backups"
      purpose        = "Disaster-Recovery"
      retention_days = var.velero_retention_days
    },
    loki = {
      name_prefix    = "loki-logs"
      description    = "Loki Distributed Log Chunks and Inverted Index"
      purpose        = "Observability"
      retention_days = var.loki_retention_days
    },
    audit = {
      name_prefix    = "cluster-audit"
      description    = "Cluster Audit Traces and Security Telemetry"
      purpose        = "Audit-Compliance"
      retention_days = var.audit_retention_days
    }
  }
}

# --------------------------------------------------------------------------------------------------
# 1. S3 Buckets with Randomized Unique Suffix
# --------------------------------------------------------------------------------------------------
resource "aws_s3_bucket" "this" {
  for_each = local.bucket_configs

  bucket        = "meshdefense-${var.environment}-${each.value.name_prefix}-${random_string.suffix.result}"
  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Name        = "meshdefense-${var.environment}-${each.value.name_prefix}"
    Description = each.value.description
    Purpose     = each.value.purpose
    Compliance  = "NIST-800-53-SC-8_SC-13_SC-28_AC-3"
  })
}

# --------------------------------------------------------------------------------------------------
# 2. Strict S3 Block Public Access (NIST 800-53 AC-3)
# --------------------------------------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "this" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --------------------------------------------------------------------------------------------------
# 3. Dedicated Customer Managed Key (CMK) Server-Side Encryption (NIST 800-53 SC-13 / SC-28)
# --------------------------------------------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# --------------------------------------------------------------------------------------------------
# 4. S3 Object Versioning (NIST 800-53 SI-12 / CP-9)
# --------------------------------------------------------------------------------------------------
resource "aws_s3_bucket_versioning" "this" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}

# --------------------------------------------------------------------------------------------------
# 5. Workload-Specific S3 Lifecycle Policies
# --------------------------------------------------------------------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id

  rule {
    id     = "clean-incomplete-multipart-uploads-and-retention"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }


    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    expiration {
      days = local.bucket_configs[each.key].retention_days
    }
  }
}

# --------------------------------------------------------------------------------------------------
# 6. Hardened Bucket Policies: Enforce TLS 1.2+ & Enforce SSE-KMS with Approved CMK
# --------------------------------------------------------------------------------------------------
resource "aws_s3_bucket_policy" "this" {
  for_each = aws_s3_bucket.this

  bucket = each.value.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # 1. Deny HTTP / Non-TLS Requests (NIST 800-53 SC-8)
      {
        Sid       = "EnforceTLSRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          each.value.arn,
          "${each.value.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      # 2. Deny uploads that do not use SSE-KMS
      {
        Sid       = "DenyUnencryptedObjectUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${each.value.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      # 3. Deny uploads that do not use the authorized Customer Managed Key (CMK)
      {
        Sid       = "DenyIncorrectKmsKey"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${each.value.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption-aws-kms-key-id" = var.kms_key_arn
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.this]
}
