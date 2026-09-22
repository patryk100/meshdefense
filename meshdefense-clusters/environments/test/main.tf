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
      Environment = "test"
      Project     = "MeshDefense"
      ManagedBy   = "Terraform"
      Compliance  = "DoD-IL6"
    }
  }
}

module "networking" {
  source = "../../modules/networking-pki"

  environment     = "test"
  region          = var.region
  vpc_id          = var.vpc_id
  vpc_cidr        = var.vpc_cidr
  subnet_ids      = var.private_subnet_ids
  route_table_ids = var.route_table_ids
  internal_domain = "test.il6.meshdefense.internal"
}

module "kubernetes" {
  source = "../../modules/kubernetes-eks"

  cluster_name       = "meshdefense-test-eks"
  environment        = "test"
  kubernetes_version = var.kubernetes_version
  vpc_id             = var.vpc_id
  vpc_cidr           = var.vpc_cidr
  private_subnet_ids = var.private_subnet_ids

  system_node_instance_types = ["m6i.xlarge"]
  system_node_desired_size   = 3
  system_node_min_size       = 2
  system_node_max_size       = 4

  workload_node_instance_types = ["m6i.2xlarge"]
  workload_node_desired_size   = 3
  workload_node_min_size       = 2
  workload_node_max_size       = 6

  tags = {
    Cluster = "meshdefense-test"
  }
}

module "bastion" {
  source = "../../modules/bastion-jumpbox"

  environment = "test"
  ami_id      = var.bastion_ami_id
  subnet_id   = var.private_subnet_ids[0]
  vpc_id      = var.vpc_id
  vpc_cidr    = var.vpc_cidr
  kms_key_arn = module.kubernetes.kms_key_arn
}
