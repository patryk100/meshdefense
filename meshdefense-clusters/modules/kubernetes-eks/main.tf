terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_prefix_list" "s3" {
  name = "com.amazonaws.${data.aws_region.current.name}.s3"
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.name
}

# --------------------------------------------------------------------------------------------------
# AWS KMS Customer Managed Key (CMK) for EKS Envelope Encryption (Optional internal fallback)
# --------------------------------------------------------------------------------------------------
resource "aws_kms_key" "eks_secrets" {
  count                   = var.kms_key_arn == null ? 1 : 0
  description             = "EKS Secrets KMS Envelope Encryption Key for ${var.cluster_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name       = "${var.cluster_name}-secrets-kms"
    Compliance = "DoD-IL6"
  })
}

resource "aws_kms_alias" "eks_secrets" {
  count         = var.kms_key_arn == null ? 1 : 0
  name          = "alias/${var.cluster_name}-k8s-secrets"
  target_key_id = aws_kms_key.eks_secrets[0].key_id
}

locals {
  kms_key_arn = var.kms_key_arn != null ? var.kms_key_arn : (length(aws_kms_key.eks_secrets) > 0 ? aws_kms_key.eks_secrets[0].arn : null)
}

# --------------------------------------------------------------------------------------------------
# CloudWatch Log Group for Comprehensive Audit Logging (NIST 800-53 AU-2 / AU-3 / AU-12)
# --------------------------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_days

  tags = merge(var.tags, {
    Name       = "${var.cluster_name}-audit-logs"
    Compliance = "NIST-800-53-AU-2_AU-3_AU-12"
  })
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
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.control_plane.name
}

resource "aws_iam_role_policy_attachment" "control_plane_vpc_resource_controller" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.control_plane.name
}

# --------------------------------------------------------------------------------------------------
# Security Group for EKS Control Plane & Workers (Zero-Trust Airgap Ingress/Egress)
# --------------------------------------------------------------------------------------------------
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for EKS control plane and nodes in airgap enclave"
  vpc_id      = var.vpc_id

  # Ingress from VPC and cluster components
  ingress {
    description = "Allow internal HTTPS to EKS API from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Allow inter-node communication within cluster security group"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Allow all outbound traffic to internal VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description     = "Allow outbound HTTPS to S3 Gateway Endpoint for ECR layer blobs"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [data.aws_prefix_list.s3.id]
  }

  tags = merge(var.tags, {
    Name                                           = "${var.cluster_name}-cluster-sg"
    "karpenter.sh/discovery"                       = var.cluster_name
    "kubernetes.io/cluster/${var.cluster_name}"     = "owned"
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
      key_arn = local.kms_key_arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.control_plane_cluster_policy,
    aws_iam_role_policy_attachment.control_plane_vpc_resource_controller,
    aws_cloudwatch_log_group.eks_cluster
  ]

  tags = merge(var.tags, {
    "meshdefense.io/environment"                = var.environment
    "karpenter.sh/discovery"                    = var.cluster_name
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })
}

# --------------------------------------------------------------------------------------------------
# Modern EKS Cluster Access Entries (Kubernetes 1.30+ Native IAM Authentication)
# --------------------------------------------------------------------------------------------------
resource "aws_eks_access_entry" "admin_roles" {
  for_each      = toset(var.admin_role_arns)
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin_roles" {
  for_each      = toset(var.admin_role_arns)
  cluster_name  = aws_eks_cluster.this.name
  policy_arn    = "arn:${local.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = each.value

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin_roles]
}

# --------------------------------------------------------------------------------------------------
# OIDC Identity Provider for IAM Roles for Service Accounts (IRSA)
# --------------------------------------------------------------------------------------------------
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-oidc-provider"
  })
}

# --------------------------------------------------------------------------------------------------
# IAM Role for Bootstrap Worker Node Group
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
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_registry_policy" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_ssm_policy" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.node_group.name
}

# --------------------------------------------------------------------------------------------------
# Hardened Launch Template for Worker Nodes (IMDSv2, KMS Storage Encryption, gp3)
# --------------------------------------------------------------------------------------------------
resource "aws_launch_template" "hardened_node" {
  name_prefix   = "${var.cluster_name}-node-template-"
  description   = "Hardened launch template for ${var.cluster_name} worker nodes"
  instance_type = var.system_node_instance_types[0]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 strictly enforced (DoD STIG requirement)
    http_put_response_hop_limit = 2          # 2 hops required for containerized pods accessing IMDS
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 80
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.ebs_kms_key_arn
      delete_on_termination = true
    }
  }

  vpc_security_group_ids = [aws_security_group.cluster.id]

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name                                           = "${var.cluster_name}-worker"
      "karpenter.sh/discovery"                       = var.cluster_name
      "kubernetes.io/cluster/${var.cluster_name}"     = "owned"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name                                           = "${var.cluster_name}-worker-root-vol"
      "karpenter.sh/discovery"                       = var.cluster_name
      "kubernetes.io/cluster/${var.cluster_name}"     = "owned"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --------------------------------------------------------------------------------------------------
# Dedicated System Node Group (Hosts CoreDNS & Karpenter in Private Subnets)
# --------------------------------------------------------------------------------------------------
resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-system-ng"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids
  ami_type        = var.ami_type

  launch_template {
    id      = aws_launch_template.hardened_node.id
    version = aws_launch_template.hardened_node.latest_version
  }

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
    Name                                           = "${var.cluster_name}-system-node"
    "karpenter.sh/discovery"                       = var.cluster_name
    "kubernetes.io/cluster/${var.cluster_name}"     = "owned"
  })

  depends_on = [
    aws_iam_role_policy_attachment.node_worker_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_registry_policy,
    aws_iam_role_policy_attachment.node_ssm_policy
  ]
}

# --------------------------------------------------------------------------------------------------
# EKS Core Managed Add-ons
# --------------------------------------------------------------------------------------------------
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "vpc-cni"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "kube-proxy"
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "coredns"

  depends_on = [aws_eks_node_group.system]
}

# --------------------------------------------------------------------------------------------------
# Karpenter Infrastructure: IAM Roles, SQS Interruption Queue & EventBridge
# --------------------------------------------------------------------------------------------------

# 1. Karpenter Controller IRSA Role
resource "aws_iam_role" "karpenter_controller" {
  count = var.enable_karpenter ? 1 : 0
  name  = "${var.cluster_name}-karpenter-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.this.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:aud" : "sts.amazonaws.com",
            "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub" : "system:serviceaccount:karpenter:karpenter"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# Policy allowing Karpenter to create and manage EC2 instances, launch templates, and instances
resource "aws_iam_policy" "karpenter_controller" {
  count       = var.enable_karpenter ? 1 : 0
  name        = "${var.cluster_name}-karpenter-controller-policy"
  description = "Permissions for Karpenter controller to dynamically provision airgap EC2 nodes"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KarpenterEC2Actions"
        Effect = "Allow"
        Action = [
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:RunInstances",
          "ec2:CreateTags",
          "ec2:TerminateInstances",
          "ec2:DeleteLaunchTemplate",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeSpotPriceHistory"
        ]
        Resource = "*"
      },
      {
        Sid    = "ConditionalEC2Termination"
        Effect = "Allow"
        Action = [
          "ec2:TerminateInstances",
          "ec2:DeleteLaunchTemplate"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/karpenter.sh/discovery" = var.cluster_name
          }
        }
      },
      {
        Sid    = "PassNodeRoleToEC2"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = aws_iam_role.karpenter_node[0].arn
      },
      {
        Sid    = "AllowKMSKeyUsageForKarpenterNodes"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = [var.ebs_kms_key_arn]
      },
      {
        Sid    = "EKSClusterDescribe"
        Effect = "Allow"
        Action = "eks:DescribeCluster"
        Resource = aws_eks_cluster.this.arn
      },
      {
        Sid    = "InterruptionQueueAccess"
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage"
        ]
        Resource = aws_sqs_queue.karpenter_interruption[0].arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  count      = var.enable_karpenter ? 1 : 0
  policy_arn = aws_iam_policy.karpenter_controller[0].arn
  role       = aws_iam_role.karpenter_controller[0].name
}

# 2. Karpenter Node IAM Role & Instance Profile
resource "aws_iam_role" "karpenter_node" {
  count = var.enable_karpenter ? 1 : 0
  name  = "${var.cluster_name}-karpenter-node-role"

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

resource "aws_iam_role_policy_attachment" "karpenter_node_worker" {
  count      = var.enable_karpenter ? 1 : 0
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.karpenter_node[0].name
}

resource "aws_iam_role_policy_attachment" "karpenter_node_cni" {
  count      = var.enable_karpenter ? 1 : 0
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.karpenter_node[0].name
}

resource "aws_iam_role_policy_attachment" "karpenter_node_registry" {
  count      = var.enable_karpenter ? 1 : 0
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.karpenter_node[0].name
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ssm" {
  count      = var.enable_karpenter ? 1 : 0
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.karpenter_node[0].name
}

resource "aws_iam_instance_profile" "karpenter_node" {
  count = var.enable_karpenter ? 1 : 0
  name  = "${var.cluster_name}-karpenter-node-profile"
  role  = aws_iam_role.karpenter_node[0].name
}

# 3. SQS Interruption Queue for Karpenter
resource "aws_sqs_queue" "karpenter_interruption" {
  count                     = var.enable_karpenter ? 1 : 0
  name                      = "${var.cluster_name}-karpenter-interruption"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-karpenter-interruption"
  })
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  count     = var.enable_karpenter ? 1 : 0
  queue_url = aws_sqs_queue.karpenter_interruption[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = ["events.amazonaws.com", "sqs.amazonaws.com"]
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.karpenter_interruption[0].arn
      }
    ]
  })
}

# EventBridge Rules to forward Spot / Instance State / Rebalance to SQS
resource "aws_cloudwatch_event_rule" "karpenter_instance_state" {
  count       = var.enable_karpenter ? 1 : 0
  name        = "${var.cluster_name}-karpenter-instance-state"
  description = "Forward EC2 instance state changes to Karpenter queue"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_instance_state" {
  count     = var.enable_karpenter ? 1 : 0
  rule      = aws_cloudwatch_event_rule.karpenter_instance_state[0].name
  target_id = "KarpenterInterruptionQueueTarget"
  arn       = aws_sqs_queue.karpenter_interruption[0].arn
}
