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
# 1. Customer Managed KMS Key with Automated Rotation (NIST 800-53 SC-13 Cryptography)
# --------------------------------------------------------------------------------------------------
module "kms_network" {
  source = "../../modules/kms-encryption"

  alias_name  = "meshdefense-${var.environment}-network"
  description = "MeshDefense Customer Managed Key for VPC Flow Logs and Network Telemetry"
  tags = {
    Role       = "Network-Telemetry-Encryption"
    Compliance = "NIST-800-53-SC-13"
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

  # Ultra-minimal sizing: 1 system node, 1 workload node
  system_node_instance_types = ["t3.xlarge"]
  system_node_desired_size   = 1
  system_node_min_size       = 1
  system_node_max_size       = 2

  workload_node_instance_types = ["t3.2xlarge"]
  workload_node_desired_size   = 1
  workload_node_min_size       = 1
  workload_node_max_size       = 3

  tags = {
    Cluster = "meshdefense-${var.environment}-minimal"
  }
}
