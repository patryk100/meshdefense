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
      Environment = "poc-minimal"
      Project     = "MeshDefense"
      ManagedBy   = "Terraform"
      CostTier    = "Low-Budget-Spot"
    }
  }
}

# 1. Private DNS
module "networking" {
  source = "../../modules/networking-pki"

  environment     = "poc"
  region          = var.region
  vpc_id          = var.vpc_id
  vpc_cidr        = var.vpc_cidr
  subnet_ids      = [var.private_subnet_ids[0]]
  route_table_ids = var.route_table_ids
  internal_domain = "poc.il6.meshdefense.internal"
}

# 2. Cost-Effective Single-Node Spot Instance Cluster
# Uses spot pricing / burstable t3.2xlarge for ~85% cloud cost reduction
module "kubernetes" {
  source = "../../modules/kubernetes-eks"

  cluster_name       = "meshdefense-poc-eks"
  environment        = "poc"
  kubernetes_version = var.kubernetes_version
  vpc_id             = var.vpc_id
  vpc_cidr           = var.vpc_cidr
  private_subnet_ids = var.private_subnet_ids

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
    Cluster = "meshdefense-poc-minimal"
  }
}
