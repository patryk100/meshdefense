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
      Environment = "dev"
      Project     = "MeshDefense"
      ManagedBy   = "Terraform"
      Compliance  = "DoD-IL6"
    }
  }
}

# 1. Private Networking & PKI
module "networking" {
  source = "../../modules/networking-pki"

  environment     = "dev"
  region          = var.region
  vpc_id          = var.vpc_id
  vpc_cidr        = var.vpc_cidr
  subnet_ids      = var.private_subnet_ids
  route_table_ids = var.route_table_ids
  internal_domain = "dev.il6.meshdefense.internal"
}

# 2. Kubernetes EKS Cluster (AWS IL6)
# Note: For Azure AKS or GCP GKE, swap this module with ../../modules/kubernetes-aks or ../../modules/kubernetes-gke
module "kubernetes" {
  source = "../../modules/kubernetes-eks"

  cluster_name       = "meshdefense-dev-eks"
  environment        = "dev"
  kubernetes_version = var.kubernetes_version
  vpc_id             = var.vpc_id
  vpc_cidr           = var.vpc_cidr
  private_subnet_ids = var.private_subnet_ids

  # Dev sizing: cost optimized
  system_node_instance_types   = ["m6i.xlarge"]
  system_node_desired_size     = 2
  system_node_min_size         = 2
  system_node_max_size         = 4

  workload_node_instance_types = ["m6i.2xlarge"]
  workload_node_desired_size   = 2
  workload_node_min_size       = 1
  workload_node_max_size       = 6

  tags = {
    Cluster = "meshdefense-dev"
  }
}

# 3. Airgap Jumpbox / Staging Bastion
module "bastion" {
  source = "../../modules/bastion-jumpbox"

  environment = "dev"
  ami_id      = var.bastion_ami_id
  subnet_id   = var.private_subnet_ids[0]
  vpc_id      = var.vpc_id
  vpc_cidr    = var.vpc_cidr
  kms_key_arn = module.kubernetes.kms_key_arn
}
