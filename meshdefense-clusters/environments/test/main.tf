terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # backend "s3" {} # Configure for IL6 private S3 bucket
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Environment = "test"
      Project     = "MeshDefense"
      ManagedBy   = "Terraform"
      Compliance  = "DoD-IL6"
    }
  }
}

# 0. Multi-Tier KMS Keyring
module "kms_keyring" {
  source = "../../modules/kms-keyring"

  environment = "test"
  tags = {
    Compliance = "DoD-IL6,NIST-800-53-SC-12_SC-13"
  }
}

# 1. Private Networking & PKI
module "networking" {
  source = "../../modules/networking-pki"

  environment     = "test"
  region          = var.region
  vpc_id          = var.vpc_id
  vpc_cidr        = var.vpc_cidr
  subnet_ids      = var.private_subnet_ids
  route_table_ids = var.route_table_ids
  internal_domain = "test.il6.meshdefense.internal"

  enable_ingress_dns_alias = var.enable_ingress_dns_alias
  ingress_nlb_dns_name     = var.ingress_nlb_dns_name
  ingress_nlb_zone_id      = var.ingress_nlb_zone_id

  tags = {
    Compliance = "DoD-IL6,NIST-800-53-SC-7"
  }
}

# 2. Hardened Multi-AZ EKS Cluster (AWS IL6 Test)
module "kubernetes" {
  source = "../../modules/kubernetes-eks"

  cluster_name       = "meshdefense-test-eks"
  environment        = "test"
  kubernetes_version = var.kubernetes_version
  vpc_id             = var.vpc_id
  vpc_cidr           = var.vpc_cidr
  private_subnet_ids = var.private_subnet_ids
  kms_key_arn        = module.kms_keyring.k8s_secrets_key_arn
  ebs_kms_key_arn    = module.kms_keyring.ebs_key_arn
  ami_type           = "AL2023_x86_64_STANDARD"
  enable_karpenter   = true

  system_node_instance_types = ["m6i.xlarge"]
  system_node_desired_size   = 2
  system_node_min_size       = 2
  system_node_max_size       = 4

  admin_role_arns = [module.bastion.bastion_iam_role_arn]

  tags = {
    Cluster = "meshdefense-test"
  }
}

# 3. Airgap Jumpbox / Staging Bastion
module "bastion" {
  source = "../../modules/bastion-jumpbox"

  environment      = "test"
  ami_id           = var.bastion_ami_id
  subnet_id        = var.private_subnet_ids[0]
  vpc_id           = var.vpc_id
  vpc_cidr         = var.vpc_cidr
  ebs_kms_key_arn  = module.kms_keyring.ebs_key_arn
  s3_kms_key_arn   = module.kms_keyring.s3_key_arn
  logs_kms_key_arn = module.kms_keyring.secrets_key_arn

  tags = {
    Compliance = "DoD-IL6,NIST-800-53-AC-3_AC-4_SC-7_SC-13"
  }
}

# 4. Air-Gapped S3 Object Storage Baseline & Lifecycle Policies (Story 1.4)
module "s3_storage" {
  source = "../../modules/s3-storage-baseline"

  environment = "test"
  kms_key_arn = module.kms_keyring.s3_key_arn

  harbor_retention_days = 90
  velero_retention_days = 60
  loki_retention_days   = 60
  audit_retention_days  = 365

  tags = {
    Compliance = "DoD-IL6,NIST-800-53-SC-8_SC-13_SC-28_AC-3"
  }
}

# 5. Multi-AZ Hardened RDS PostgreSQL for Platform State (Story 1.5)
module "rds" {
  source = "../../modules/rds-postgresql"

  environment         = "test"
  vpc_id              = var.vpc_id
  subnet_ids          = var.private_subnet_ids
  allowed_cidr_blocks = [var.vpc_cidr]
  allowed_security_group_ids = [
    module.bastion.bastion_security_group_id,
    module.kubernetes.cluster_security_group_id
  ]

  instance_class        = "db.t3.large"
  allocated_storage     = 30
  max_allocated_storage = 100
  multi_az              = true

  kms_key_arn         = module.kms_keyring.rds_key_arn
  secrets_kms_key_arn = module.kms_keyring.secrets_key_arn

  tags = {
    Compliance = "DoD-IL6,NIST-800-53-SC-7_SC-8_SC-13_CP-9"
  }
}

# 6. Granular IRSA Factory & OIDC Trust Architecture (Story 2.3)
module "irsa_factory" {
  source = "../../modules/irsa-factory"

  environment       = "test"
  cluster_name      = module.kubernetes.cluster_name
  oidc_provider_arn = module.kubernetes.oidc_provider_arn
  oidc_provider_url = module.kubernetes.oidc_provider_url

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
  logging_kms_key_arns = [module.kms_keyring.secrets_key_arn, module.kms_keyring.s3_key_arn]

  # 4. HashiCorp Vault (KMS Auto-Unseal)
  enable_vault      = true
  vault_kms_key_arn = module.kms_keyring.secrets_key_arn

  # 5. AWS EBS CSI Driver (Storage Provisioner)
  enable_ebs_csi  = true
  ebs_kms_key_arn = module.kms_keyring.ebs_key_arn

  # 6. Flux v2 GitOps Source & Helm Controllers (Story 2.5)
  enable_flux         = true
  flux_s3_bucket_arns = [module.s3_storage.bucket_arns["harbor"]]
  flux_kms_key_arns   = [module.kms_keyring.s3_key_arn, module.kms_keyring.secrets_key_arn]

  # 7. AWS Load Balancer Controller (Story 3.2 - Air-Gapped NLB Provisioning)
  enable_aws_load_balancer_controller = true

  tags = {
    Role       = "IRSA-ServiceAccounts"
    Compliance = "DoD-IL6,NIST-800-53-AC-3_AC-6_SC-12_SC-13"
  }
}

# 7. Seed ECR Registry & Day-0 Air-Gap Bootstrap Repositories (Story 3.1)
module "airgap_seed_registry" {
  source = "../../modules/airgap-registry"

  environment = "test"
  additional_repositories = [
    "external-secrets/external-secrets"
  ]

  tags = {
    Role       = "Day-0-Air-Gap-Bootstrap"
    Compliance = "DoD-IL6_NIST-800-53-SC-8_SC-13_RA-5"
  }
}
