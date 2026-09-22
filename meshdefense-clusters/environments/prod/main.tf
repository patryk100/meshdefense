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
      Environment    = "prod"
      Project        = "MeshDefense"
      ManagedBy      = "Terraform"
      Compliance     = "DoD-IL6"
      Classification = "Secret"
    }
  }
}

# 1. Private Route53 Zone & Isolated VPC Endpoints
module "networking" {
  source = "../../modules/networking-pki"

  environment     = "prod"
  region          = var.region
  vpc_id          = var.vpc_id
  vpc_cidr        = var.vpc_cidr
  subnet_ids      = var.private_subnet_ids
  route_table_ids = var.route_table_ids
  internal_domain = "prod.il6.meshdefense.internal"
}

# 2. Hardened Multi-AZ EKS Cluster (AWS IL6 Secret Region)
module "kubernetes" {
  source = "../../modules/kubernetes-eks"

  cluster_name       = "meshdefense-prod-eks"
  environment        = "prod"
  kubernetes_version = var.kubernetes_version
  vpc_id             = var.vpc_id
  vpc_cidr           = var.vpc_cidr
  private_subnet_ids = var.private_subnet_ids

  # Production sizing: Multi-AZ HA, dedicated compute pools
  ami_type                   = "BOTTLEROCKET_x86_64" # Immutable, minimal attack surface
  system_node_instance_types = ["m6i.2xlarge"]
  system_node_desired_size   = 3
  system_node_min_size       = 3
  system_node_max_size       = 6

  workload_node_instance_types = ["m6i.4xlarge"]
  workload_node_desired_size   = 6
  workload_node_min_size       = 3
  workload_node_max_size       = 15

  tags = {
    Cluster        = "meshdefense-prod"
    Classification = "Secret"
    STIGEnforced   = "true"
  }
}

# 3. High-Security Staging Bastion (Session Manager only)
module "bastion" {
  source = "../../modules/bastion-jumpbox"

  environment = "prod"
  ami_id      = var.bastion_ami_id
  subnet_id   = var.private_subnet_ids[0]
  vpc_id      = var.vpc_id
  vpc_cidr    = var.vpc_cidr
  kms_key_arn = module.kubernetes.kms_key_arn
}
