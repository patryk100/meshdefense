terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# --------------------------------------------------------------------------------------------------
# Multi-Tier KMS Keyring for Defense-in-Depth Cryptographic Separation (NIST 800-53 SC-12 / SC-13)
# --------------------------------------------------------------------------------------------------

# 1. Kubernetes Secrets Envelope Encryption Key (EKS Control Plane)
module "k8s_secrets_key" {
  source = "../kms-encryption"

  alias_name              = "meshdefense-${var.environment}-k8s-secrets"
  description             = "MeshDefense Envelope Encryption CMK for Kubernetes Secrets (${var.environment})"
  service_type            = "general"
  deletion_window_in_days = var.deletion_window_in_days
  admin_principals        = var.admin_principals
  key_users               = var.k8s_secrets_key_users
  tags                    = merge(var.tags, { Tier = "K8s-Envelope", Service = "Kubernetes" })
}

# 2. EBS Volume Storage Encryption Key (Worker Node Root/Data Volumes & PVCs)
module "ebs_key" {
  source = "../kms-encryption"

  alias_name              = "meshdefense-${var.environment}-ebs"
  description             = "MeshDefense Storage CMK for EC2/EKS EBS Volumes (${var.environment})"
  service_type            = "ebs"
  deletion_window_in_days = var.deletion_window_in_days
  admin_principals        = var.admin_principals
  key_users               = var.ebs_key_users
  tags                    = merge(var.tags, { Tier = "Block-Storage", Service = "EBS" })
}

# 3. S3 Object Storage Encryption Key (Artifacts, Helm Charts, Backups)
module "s3_key" {
  source = "../kms-encryption"

  alias_name              = "meshdefense-${var.environment}-s3"
  description             = "MeshDefense Object Storage CMK for S3 Buckets (${var.environment})"
  service_type            = "s3"
  deletion_window_in_days = var.deletion_window_in_days
  admin_principals        = var.admin_principals
  key_users               = var.s3_key_users
  tags                    = merge(var.tags, { Tier = "Object-Storage", Service = "S3" })
}

# 4. Relational Database Encryption Key (PostgreSQL / RDS / State persistence)
module "rds_key" {
  source = "../kms-encryption"

  alias_name              = "meshdefense-${var.environment}-rds"
  description             = "MeshDefense Database CMK for RDS Instances (${var.environment})"
  service_type            = "rds"
  deletion_window_in_days = var.deletion_window_in_days
  admin_principals        = var.admin_principals
  key_users               = var.rds_key_users
  tags                    = merge(var.tags, { Tier = "Database", Service = "RDS" })
}

# 5. Secrets Manager Encryption Key (Application & Bootstrap Credentials)
module "secrets_key" {
  source = "../kms-encryption"

  alias_name              = "meshdefense-${var.environment}-secrets"
  description             = "MeshDefense Secrets CMK for AWS Secrets Manager (${var.environment})"
  service_type            = "secrets"
  deletion_window_in_days = var.deletion_window_in_days
  admin_principals        = var.admin_principals
  key_users               = var.secrets_key_users
  tags                    = merge(var.tags, { Tier = "Secrets-Management", Service = "SecretsManager" })
}
