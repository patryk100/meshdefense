terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# --------------------------------------------------------------------------------------------------
# IAM Role & Instance Profile for Secure Air-Gap Bastion (SSM Managed)
# --------------------------------------------------------------------------------------------------
resource "aws_iam_role" "bastion" {
  name = "${var.environment}-airgap-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  policy_arn = "arn:aws-us-gov:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.bastion.name
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.environment}-bastion-profile"
  role = aws_iam_role.bastion.name
}

# --------------------------------------------------------------------------------------------------
# Security Group for Bastion (No Inbound Internet, Internal Only)
# --------------------------------------------------------------------------------------------------
resource "aws_security_group" "bastion" {
  name        = "${var.environment}-airgap-bastion-sg"
  description = "Air-gap bastion security group"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound traffic to internal VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = var.tags
}

# --------------------------------------------------------------------------------------------------
# EC2 Bastion Instance (Pre-loaded with Airgap Tools)
# --------------------------------------------------------------------------------------------------
resource "aws_instance" "bastion" {
  ami                  = var.ami_id
  instance_type        = var.instance_type
  subnet_id            = var.subnet_id
  iam_instance_profile = aws_iam_instance_profile.bastion.name
  vpc_security_group_ids = [aws_security_group.bastion.id]

  root_block_device {
    volume_size           = 200 # Adequate for container image tarballs and Big Bang bundles
    volume_type           = "gp3"
    encrypted             = true
    kms_key_id            = var.kms_key_arn
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              # Air-gap bastion initialization
              echo "Initializing MeshDefense Airgap Bastion..."
              # Verification of tools
              EOF

  tags = merge(var.tags, {
    Name = "${var.environment}-airgap-bastion"
  })
}
