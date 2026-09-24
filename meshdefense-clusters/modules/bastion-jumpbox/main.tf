terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.name
}

# --------------------------------------------------------------------------------------------------
# Dynamic Discovery of latest Amazon Linux 2023 AMI if custom AMI not supplied
# --------------------------------------------------------------------------------------------------
data "aws_ami" "al2023" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  selected_ami_id = var.ami_id != null ? var.ami_id : data.aws_ami.al2023[0].id
}

# --------------------------------------------------------------------------------------------------
# Audit Logging Targets: CloudWatch Log Group & S3 Audit Bucket (NIST 800-53 AU-2 / AU-3 / AU-12)
# --------------------------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "ssm_sessions" {
  name              = "/aws/ssm/${var.environment}-bastion-sessions"
  retention_in_days = 90
  kms_key_id        = var.logs_kms_key_arn

  tags = merge(var.tags, {
    Name       = "${var.environment}-bastion-ssm-logs"
    Compliance = "NIST-800-53-AU-2_AU-3_AU-12"
  })
}

resource "random_string" "bucket_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket" "ssm_sessions" {
  bucket        = "meshdefense-${var.environment}-ssm-sessions-${random_string.bucket_suffix.result}"
  force_destroy = true

  tags = merge(var.tags, {
    Name       = "${var.environment}-bastion-ssm-session-bucket"
    Compliance = "NIST-800-53-AU-2_AU-3_AU-12"
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ssm_sessions" {
  bucket = aws_s3_bucket.ssm_sessions.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.s3_kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "ssm_sessions" {
  bucket = aws_s3_bucket.ssm_sessions.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "enforce_tls" {
  bucket = aws_s3_bucket.ssm_sessions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceTLSRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.ssm_sessions.arn,
          "${aws_s3_bucket.ssm_sessions.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# --------------------------------------------------------------------------------------------------
# SSM Document Enforcing Encrypted CloudWatch & S3 Session Logging
# --------------------------------------------------------------------------------------------------
resource "aws_ssm_document" "session_preferences" {
  name          = "SSM-SessionManagerRunShell"
  document_type = "Session"

  content = jsonencode({
    schemaVersion = "1.0"
    description   = "MeshDefense Mandated SSM Session Logging Configuration"
    sessionType   = "Standard_Stream"
    inputs = {
      s3BucketName                = aws_s3_bucket.ssm_sessions.id
      s3KeyPrefix                 = "sessions"
      s3EncryptionEnabled         = true
      cloudWatchLogGroupName      = aws_cloudwatch_log_group.ssm_sessions.name
      cloudWatchEncryptionEnabled = true
      kmsKeyId                    = var.logs_kms_key_arn
      idleSessionTimeout          = "20"
      maxSessionDuration          = "60"
    }
  })
}

# --------------------------------------------------------------------------------------------------
# IAM Role & Instance Profile for Secure Air-Gap Bastion (SSM Managed + Session Auditing)
# --------------------------------------------------------------------------------------------------
resource "aws_iam_role" "bastion" {
  name = "${var.environment}-airgap-bastion-role"

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

resource "aws_iam_role_policy_attachment" "ssm_core" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.bastion.name
}

resource "aws_iam_policy" "ssm_session_logging" {
  name        = "${var.environment}-bastion-session-logging"
  description = "Allows Bastion SSM Agent to stream session logs to CloudWatch and S3 using KMS keys"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.ssm_sessions.arn}:*"
        ]
      },
      {
        Sid    = "AllowS3Logging"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetEncryptionConfiguration"
        ]
        Resource = [
          "${aws_s3_bucket.ssm_sessions.arn}/*",
          aws_s3_bucket.ssm_sessions.arn
        ]
      },
      {
        Sid    = "AllowKMSKeyUsage"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = [
          var.ebs_kms_key_arn,
          var.s3_kms_key_arn,
          var.logs_kms_key_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_session_logging" {
  policy_arn = aws_iam_policy.ssm_session_logging.arn
  role       = aws_iam_role.bastion.name
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.environment}-bastion-profile"
  role = aws_iam_role.bastion.name
}

# --------------------------------------------------------------------------------------------------
# Security Group for Bastion: Zero Inbound Ports Allowed (NIST 800-53 SC-7)
# --------------------------------------------------------------------------------------------------
resource "aws_security_group" "bastion" {
  name        = "${var.environment}-airgap-bastion-sg"
  description = "Air-gap bastion security group - Zero inbound ports, HTTPS outbound to VPC"
  vpc_id      = var.vpc_id

  # ZERO ingress blocks - No open ports, no SSH, accessible exclusively via SSM

  egress {
    description = "Allow HTTPS outbound to VPC endpoints and internal services"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow PostgreSQL outbound to internal databases"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }


  tags = merge(var.tags, {
    Name       = "${var.environment}-bastion-sg"
    Compliance = "NIST-800-53-SC-7"
  })
}

# --------------------------------------------------------------------------------------------------
# EC2 Bastion Instance (Non-Public, Private Subnet, Encrypted Root with EBS CMK)
# --------------------------------------------------------------------------------------------------
resource "aws_instance" "bastion" {
  ami                         = local.selected_ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 strictly enforced (DoD STIG requirement)
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    kms_key_id            = var.ebs_kms_key_arn
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              echo "Initializing MeshDefense Day-0 Airgap Bastion..."
              # Ensure amazon-ssm-agent is active
              systemctl enable amazon-ssm-agent
              systemctl restart amazon-ssm-agent
              echo "Bastion ready for SSM Session Manager connections."
              EOF

  tags = merge(var.tags, {
    Name        = "${var.environment}-airgap-bastion"
    Role        = "Day-0-Bootstrap-Bastion"
    Compliance  = "NIST-800-53-AC-3_AC-4_SC-7_SC-13"
  })
}
