terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Environment = var.environment
      Project     = "MeshDefense"
      ManagedBy   = "Terraform"
      Compliance  = "NIST-800-53"
      CostTier    = "Low-Budget-Minimal"
    }
  }
}

# --------------------------------------------------------------------------------------------------
# 1. Customer Managed KMS Keys with Automated Rotation (NIST 800-53 SC-12 / SC-13)
# --------------------------------------------------------------------------------------------------
# Dedicated Network Telemetry & Flow Log Encryption CMK
module "kms_network" {
  source = "../../modules/kms-encryption"

  alias_name   = "meshdefense-${var.environment}-network"
  description  = "MeshDefense Customer Managed Key for VPC Flow Logs and Network Telemetry"
  service_type = "cloudwatch"
  tags = {
    Role       = "Network-Telemetry-Encryption"
    Compliance = "NIST-800-53-SC-13"
  }
}

# Multi-Tier KMS Keyring: K8s Secrets, EBS Volumes, S3 Buckets, RDS Instances, Secrets Manager
module "kms_keyring" {
  source = "../../modules/kms-keyring"

  environment = var.environment
  tags = {
    Compliance = "NIST-800-53-SC-12_SC-13"
  }

}


# --------------------------------------------------------------------------------------------------
# 2. Isolated Multi-AZ VPC Architecture (NIST 800-53 SC-7 Boundary Protection)
# Zero Internet Gateways, Zero NAT Gateways, Multi-AZ Private Subnets
# --------------------------------------------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc-isolated"

  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  az_count     = var.az_count
  cluster_name = "meshdefense-${var.environment}-eks"
  kms_key_arn  = module.kms_network.key_arn

  tags = {
    Architecture = "Isolated-Zero-IGW"
    Compliance   = "NIST-800-53-SC-7"
  }
}

# --------------------------------------------------------------------------------------------------
# 3. Strict S3 Gateway & Interface VPC Endpoints + Private DNS (NIST 800-53 SC-7)
# --------------------------------------------------------------------------------------------------
module "networking" {
  source = "../../modules/networking-pki"

  environment     = var.environment
  region          = var.region
  vpc_id          = module.vpc.vpc_id
  vpc_cidr        = module.vpc.vpc_cidr
  subnet_ids      = module.vpc.private_subnet_ids
  route_table_ids = module.vpc.route_table_ids
  internal_domain = "${var.environment}.il6.meshdefense.internal"

  tags = {
    Role       = "Private-Endpoints-and-DNS"
    Compliance = "NIST-800-53-SC-7"
  }
}

# --------------------------------------------------------------------------------------------------
# 4. Optional: Kubernetes EKS Cluster on Isolated Network
# --------------------------------------------------------------------------------------------------
module "kubernetes" {
  count  = var.enable_eks ? 1 : 0
  source = "../../modules/kubernetes-eks"

  cluster_name       = "meshdefense-${var.environment}-eks"
  environment        = var.environment
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr
  private_subnet_ids = module.vpc.private_subnet_ids
  kms_key_arn        = module.kms_keyring.k8s_secrets_key_arn
  ebs_kms_key_arn    = module.kms_keyring.ebs_key_arn
  ami_type           = "AL2023_x86_64_STANDARD"
  enable_karpenter   = true

  # Ultra-minimal sizing: 1 system bootstrap node
  system_node_instance_types = ["t3.xlarge"]
  system_node_desired_size   = 1
  system_node_min_size       = 1
  system_node_max_size       = 2

  admin_role_arns    = var.enable_bastion ? [module.bastion[0].bastion_iam_role_arn] : []

  tags = {
    Cluster = "meshdefense-${var.environment}-minimal"
  }
}


# --------------------------------------------------------------------------------------------------
# 5. Air-Gapped S3 Object Storage Baseline & Lifecycle Policies (Story 1.4)
# --------------------------------------------------------------------------------------------------
module "s3_storage" {
  source = "../../modules/s3-storage-baseline"

  environment = var.environment
  kms_key_arn = module.kms_keyring.s3_key_arn

  # Minimal poc retention settings for quick validation
  harbor_retention_days = 90
  velero_retention_days = 60
  loki_retention_days   = 90
  audit_retention_days  = 365

  tags = {
    Compliance = "NIST-800-53-SC-8_SC-13_SC-28_AC-3"
  }
}

# --------------------------------------------------------------------------------------------------
# 6. Day-0 Ephemeral Administrative Bastion & SSM Session Manager (Story 1.3)
# --------------------------------------------------------------------------------------------------
module "bastion" {
  count  = var.enable_bastion ? 1 : 0
  source = "../../modules/bastion-jumpbox"

  environment              = var.environment
  instance_type            = var.bastion_instance_type
  subnet_id                = module.vpc.private_subnet_ids[0]
  vpc_id                   = module.vpc.vpc_id
  vpc_cidr                 = module.vpc.vpc_cidr
  ebs_kms_key_arn          = module.kms_keyring.ebs_key_arn
  s3_kms_key_arn           = module.kms_keyring.s3_key_arn
  logs_kms_key_arn         = module.kms_network.key_arn
  root_volume_size         = 30 # Cost-effective size for minimal poc testing
  bootstrap_s3_bucket_arns = values(module.s3_storage.bucket_arns)

  tags = {
    Role       = "Day-0-Bootstrap-Bastion"
    Compliance = "NIST-800-53-AC-3_AC-4_SC-7_SC-13"
  }
}

# --------------------------------------------------------------------------------------------------
# 7. Multi-AZ Hardened RDS PostgreSQL for Platform State (Story 1.5)
# --------------------------------------------------------------------------------------------------
module "rds" {
  count  = var.enable_rds ? 1 : 0
  source = "../../modules/rds-postgresql"

  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnet_ids
  allowed_cidr_blocks = [module.vpc.vpc_cidr]
  allowed_security_group_ids = [
    try(module.bastion[0].bastion_security_group_id, null)
  ]

  # Cost-conscious minimal sizing for validation
  instance_class        = "db.t4g.micro"
  allocated_storage     = 20
  max_allocated_storage = 50
  multi_az              = var.rds_multi_az

  # Cryptographic separation
  kms_key_arn         = module.kms_keyring.rds_key_arn
  secrets_kms_key_arn = module.kms_keyring.secrets_key_arn

  tags = {
    Compliance = "NIST-800-53-SC-7_SC-8_SC-13_CP-9"
  }
}

# --------------------------------------------------------------------------------------------------
# 8. Granular IRSA Factory & OIDC Trust Architecture (Story 2.3)
# --------------------------------------------------------------------------------------------------
module "irsa_factory" {
  count  = var.enable_eks ? 1 : 0
  source = "../../modules/irsa-factory"

  environment       = var.environment
  cluster_name      = module.kubernetes[0].cluster_name
  oidc_provider_arn = module.kubernetes[0].oidc_provider_arn
  oidc_provider_url = module.kubernetes[0].oidc_provider_url

  # 1. External Secrets Operator (ESO)
  enable_external_secrets       = true
  external_secrets_kms_key_arns = [module.kms_keyring.secrets_key_arn]

  # 2. Velero (Cluster Backup & DR)
  enable_velero      = true
  velero_bucket_arn  = module.s3_storage.bucket_arns["velero"]
  velero_kms_key_arn = module.kms_keyring.s3_key_arn

  # 3. Vector / Fluent-Bit (Distributed Logging Shipper)
  enable_logging       = true
  logging_bucket_arn   = module.s3_storage.bucket_arns["loki"]
  logging_kms_key_arns = [module.kms_network.key_arn, module.kms_keyring.s3_key_arn]

  # 4. HashiCorp Vault (KMS Auto-Unseal)
  enable_vault      = true
  vault_kms_key_arn = module.kms_keyring.secrets_key_arn

  # 5. AWS EBS CSI Driver (Storage Provisioner)
  enable_ebs_csi  = true
  ebs_kms_key_arn = module.kms_keyring.ebs_key_arn

  # 6. Flux v2 GitOps Source & Helm Controllers (Story 2.5)
  enable_flux       = true
  flux_s3_bucket_arns = [module.s3_storage.bucket_arns["harbor"]]
  flux_kms_key_arns   = [module.kms_keyring.s3_key_arn, module.kms_keyring.secrets_key_arn]

  tags = {
    Role       = "IRSA-ServiceAccounts"
    Compliance = "NIST-800-53-AC-3_AC-6_SC-12_SC-13"
  }
}



