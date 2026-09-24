terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_partition" "current" {}

# --------------------------------------------------------------------------------------------------
# AWS KMS Customer Managed Key (CMK) for EKS Envelope Encryption
# --------------------------------------------------------------------------------------------------
resource "aws_kms_key" "eks_secrets" {
  description             = "EKS Secrets KMS Envelope Encryption Key for ${var.cluster_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name       = "${var.cluster_name}-secrets-kms"
    Compliance = "DoD-IL6"
  })
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${var.cluster_name}-k8s-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}

# --------------------------------------------------------------------------------------------------
# IAM Role for EKS Control Plane
# --------------------------------------------------------------------------------------------------
resource "aws_iam_role" "control_plane" {
  name = "${var.cluster_name}-control-plane-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "control_plane_cluster_policy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.control_plane.name
}

resource "aws_iam_role_policy_attachment" "control_plane_vpc_resource_controller" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.control_plane.name
}

# --------------------------------------------------------------------------------------------------
# Security Group for EKS Control Plane & Workers (Zero-Trust Airgap Ingress/Egress)
# --------------------------------------------------------------------------------------------------
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for EKS control plane in IL6 enclave"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow cluster control plane to communicate with worker nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-cluster-sg"
  })
}

# --------------------------------------------------------------------------------------------------
# AWS EKS Cluster (Strict Air-Gap IL6 Configuration: Private Endpoint Only)
# --------------------------------------------------------------------------------------------------
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.control_plane.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = false # CRITICAL FOR AIRGAP / IL6 COMPLIANCE
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks_secrets.arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_iam_role_policy_attachment.control_plane_cluster_policy,
    aws_iam_role_policy_attachment.control_plane_vpc_resource_controller
  ]

  tags = merge(var.tags, {
    "meshdefense.io/environment" = var.environment
  })
}

# --------------------------------------------------------------------------------------------------
# IAM Role for Managed Worker Node Groups
# --------------------------------------------------------------------------------------------------
resource "aws_iam_role" "node_group" {
  name = "${var.cluster_name}-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node_worker_policy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_registry_policy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}

# --------------------------------------------------------------------------------------------------
# Dedicated Node Groups for Big Bang (System & Workload Pools)
# --------------------------------------------------------------------------------------------------
# System Pool (Core Big Bang, Istio control plane, Gatekeeper, Flux)
resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-system-ng"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids
  ami_type        = var.ami_type # AL2_x86_64 or BOTTLEROCKET_x86_64
  instance_types  = var.system_node_instance_types

  scaling_config {
    desired_size = var.system_node_desired_size
    max_size     = var.system_node_max_size
    min_size     = var.system_node_min_size
  }

  labels = {
    "node.meshdefense.io/role" = "system"
    "platformone.dso.mil/tier" = "core"
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-system-node"
  })

  depends_on = [
    aws_iam_role_policy_attachment.node_worker_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_registry_policy
  ]
}

# Workload Pool (Big Bang Addons: GitLab, SonarQube, Monitoring, Custom apps)
resource "aws_eks_node_group" "workload" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-workload-ng"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids
  ami_type        = var.ami_type
  instance_types  = var.workload_node_instance_types

  scaling_config {
    desired_size = var.workload_node_desired_size
    max_size     = var.workload_node_max_size
    min_size     = var.workload_node_min_size
  }

  labels = {
    "node.meshdefense.io/role" = "workload"
    "platformone.dso.mil/tier" = "apps"
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-workload-node"
  })

  depends_on = [
    aws_iam_role_policy_attachment.node_worker_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_registry_policy
  ]
}
