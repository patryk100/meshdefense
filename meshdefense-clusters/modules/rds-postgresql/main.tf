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

data "aws_partition" "current" {}
data "aws_region" "current" {}

# --------------------------------------------------------------------------------------------------
# 1. Multi-AZ Private DB Subnet Group (NIST 800-53 SC-7 Boundary Protection)
# --------------------------------------------------------------------------------------------------
resource "aws_db_subnet_group" "this" {
  name        = "meshdefense-${var.environment}-db-subnets"
  description = "MeshDefense multi-AZ private DB subnet group for ${var.environment}"
  subnet_ids  = var.subnet_ids

  tags = merge(var.tags, {
    Name       = "meshdefense-${var.environment}-db-subnets"
    Compliance = "NIST-800-53-SC-7"
  })
}

# --------------------------------------------------------------------------------------------------
# 2. Hardened Database Security Group (Zero Public Ingress, Port 5432 Restricted)
# --------------------------------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "meshdefense-${var.environment}-rds-sg"
  description = "Security group for hardened private RDS PostgreSQL instance"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = length(var.allowed_cidr_blocks) > 0 ? [1] : []
    content {
      description = "PostgreSQL ingress from authorized VPC CIDR blocks"
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
    }
  }

  dynamic "ingress" {
    for_each = var.allowed_security_group_ids
    content {
      description     = "PostgreSQL ingress from authorized client security groups"
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  tags = merge(var.tags, {
    Name       = "meshdefense-${var.environment}-rds-sg"
    Compliance = "NIST-800-53-SC-7"
  })
}

# --------------------------------------------------------------------------------------------------
# 3. DB Parameter Group: Enforce TLS 1.2+ & Audit Telemetry (NIST 800-53 SC-8 / AU-2)
# --------------------------------------------------------------------------------------------------
resource "aws_db_parameter_group" "this" {
  name        = "meshdefense-${var.environment}-pg16-hardened"
  family      = "postgres16"
  description = "MeshDefense hardened PostgreSQL 16 parameters enforcing TLS 1.2+ and logging"

  # Force SSL/TLS on all client connections (rejects plaintext TCP)
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  # Enforce TLS 1.2 minimum protocol version
  parameter {
    name  = "ssl_min_protocol_version"
    value = "TLSv1.2"
  }

  # DoD STIG / NIST 800-53 Database Audit Logging
  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_duration"
    value = "1"
  }

  tags = merge(var.tags, {
    Name       = "meshdefense-${var.environment}-pg16-parameters"
    Compliance = "NIST-800-53-SC-8_AU-2"
  })
}

# --------------------------------------------------------------------------------------------------
# 4. Master Credential Generation & AWS Secrets Manager (Encrypted with Secrets CMK)
# --------------------------------------------------------------------------------------------------
resource "random_password" "master_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_string" "secret_suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "meshdefense/${var.environment}/rds/master-credentials-${random_string.secret_suffix.result}"
  description = "Master database credentials for ${var.environment} RDS PostgreSQL"
  kms_key_id  = var.secrets_kms_key_arn

  tags = merge(var.tags, {
    Name       = "meshdefense-${var.environment}-rds-credentials"
    Compliance = "NIST-800-53-IA-5_SC-13"
  })
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    engine   = "postgres"
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    username = var.admin_username
    password = random_password.master_password.result
    database = var.database_name
  })
}

# --------------------------------------------------------------------------------------------------
# 5. Multi-AZ Hardened RDS PostgreSQL Database Instance (NIST 800-53 SC-13 / CP-9)
# --------------------------------------------------------------------------------------------------
resource "aws_db_instance" "this" {
  identifier = "meshdefense-${var.environment}-postgresql"

  engine               = "postgres"
  engine_version       = "16.3"
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type         = "gp3"

  # CMK Encryption at Rest (NIST 800-53 SC-13 / SC-28)
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  # Network & Placement
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # High Availability (Multi-AZ)
  multi_az = var.multi_az

  # Database Initialization
  db_name  = var.database_name
  username = var.admin_username
  password = random_password.master_password.result

  # Parameter Group enforcing TLS 1.2+
  parameter_group_name = aws_db_parameter_group.this.name

  # IAM Database Authentication (passwordless STS token auth)
  iam_database_authentication_enabled = true

  # Automated Backups & Maintenance
  backup_retention_period   = var.backup_retention_period
  backup_window             = "03:00-04:00"
  maintenance_window        = "sun:04:30-sun:05:30"
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot     = true

  # Deletion safeguards
  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot

  tags = merge(var.tags, {
    Name        = "meshdefense-${var.environment}-postgresql"
    Role        = "Platform-State-Storage"
    Compliance  = "NIST-800-53-SC-7_SC-8_SC-13_CP-9"
  })
}
