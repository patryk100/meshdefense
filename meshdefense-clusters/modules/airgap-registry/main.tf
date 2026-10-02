# ==================================================================================================
# MeshDefense Air-Gap Seed ECR Registry Module (Story 3.1)
# Provisions private, KMS-encrypted AWS Elastic Container Registry (ECR) repositories
# to host minimal bootstrap container images (Flux, CoreDNS, VPC CNI, Harbor operator, Cert-Manager)
# enabling zero-IGW cluster initialization before in-cluster Harbor is active.
# Complies with NIST 800-53 SC-8 (Transmission Confidentiality), SC-13 (Cryptographic Protection),
# and DoD Cloud SRG IL6 controls.
# ==================================================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  # Default minimal bootstrap image repositories required for cluster initialization
  default_bootstrap_repositories = [
    # Flux v2 core GitOps controllers
    "fluxcd/source-controller",
    "fluxcd/kustomize-controller",
    "fluxcd/helm-controller",
    "fluxcd/notification-controller",
    "fluxcd/image-automation-controller",
    "fluxcd/image-reflector-controller",

    # Core Networking & DNS bootstrap images
    "eks/coredns",
    "eks/kube-proxy",
    "amazon-k8s-cni",
    "amazon-k8s-cni-init",
    "amazon/aws-network-policy-agent",

    # Security & Certificate Management
    "cert-manager/cert-manager-controller",
    "cert-manager/cert-manager-cainjector",
    "cert-manager/cert-manager-webhook",

    # Harbor Operator & In-Cluster Registry Bootstrap
    "goharbor/harbor-core",
    "goharbor/harbor-portal",
    "goharbor/registry-photon",
    "goharbor/harbor-db",
    "goharbor/redis-photon",
    "goharbor/trivy-adapter-photon",
    "goharbor/harbor-jobservice",

    # AWS Load Balancer Controller (Story 3.2 - Air-Gapped NLB Provisioning)
    "amazon/aws-load-balancer-controller",

    # Airgap OCI packages
    "meshdefense/charts"
  ]

  # Consolidated unique list of repositories
  all_repositories = distinct(concat(local.default_bootstrap_repositories, var.additional_repositories))
}

# --------------------------------------------------------------------------------------------------
# Private AWS ECR Repositories with KMS Encryption & Automated Image Scanning
# --------------------------------------------------------------------------------------------------
resource "aws_ecr_repository" "bootstrap" {
  for_each = toset(local.all_repositories)

  name                 = each.value
  image_tag_mutability = var.image_tag_mutability

  # Automated vulnerability scanning on push (NIST 800-53 RA-5)
  image_scanning_configuration {
    scan_on_push = true
  }

  # KMS encryption: Customer-Managed Key (CMK) or AWS managed AES-256
  encryption_configuration {
    encryption_type = var.kms_key_arn != null && var.kms_key_arn != "" ? "KMS" : "AES256"
    kms_key         = var.kms_key_arn != null && var.kms_key_arn != "" ? var.kms_key_arn : null
  }

  tags = merge(var.tags, {
    Name       = each.value
    Role       = "Seed-ECR-Bootstrap-Registry"
    Tier       = "Day-0-Air-Gap"
    Compliance = "DoD-IL6_NIST-800-53-SC-8_SC-13_RA-5"
  })
}

# --------------------------------------------------------------------------------------------------
# ECR Repository Lifecycle Policy
# Protects against disk runaway while retaining immutable release tags
# --------------------------------------------------------------------------------------------------
resource "aws_ecr_lifecycle_policy" "bootstrap" {
  for_each   = aws_ecr_repository.bootstrap
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain tagged bootstrap releases, expire untagged blobs after 14 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
