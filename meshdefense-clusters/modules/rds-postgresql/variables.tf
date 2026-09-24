variable "environment" {
  type        = string
  description = "Environment identifier (e.g., poc-minimal, dev, prod)"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where RDS is hosted"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs across multiple AZs for the DB subnet group"
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  default     = []
  description = "List of CIDR blocks permitted to connect to PostgreSQL (5432)"
}

variable "allowed_security_group_ids" {
  type        = list(string)
  default     = []
  description = "List of Security Group IDs permitted to connect to PostgreSQL (5432)"
}

variable "instance_class" {
  type        = string
  default     = "db.t4g.micro"
  description = "RDS instance class (e.g. db.t4g.micro for minimal poc, db.m6i.xlarge for prod)"
}

variable "allocated_storage" {
  type        = number
  default     = 20
  description = "Allocated storage size in GB"
}

variable "max_allocated_storage" {
  type        = number
  default     = 100
  description = "Maximum storage size in GB for autoscaling"
}

variable "multi_az" {
  type        = bool
  default     = true
  description = "Enable Multi-AZ deployment for high availability"
}

variable "database_name" {
  type        = string
  default     = "meshdefense"
  description = "Default database name to create"
}

variable "admin_username" {
  type        = string
  default     = "meshadmin"
  description = "Master username for PostgreSQL"
}

variable "kms_key_arn" {
  type        = string
  description = "Customer Managed Key (CMK) ARN for RDS storage encryption"
}

variable "secrets_kms_key_arn" {
  type        = string
  description = "Customer Managed Key (CMK) ARN for Secrets Manager encryption"
}

variable "backup_retention_period" {
  type        = number
  default     = 7
  description = "Number of days to retain automated backups (1 to 35)"
}

variable "deletion_protection" {
  type        = bool
  default     = false
  description = "Protect the database from accidental deletion"
}

variable "skip_final_snapshot" {
  type        = bool
  default     = true
  description = "Skip final snapshot on deletion (set to false in production)"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags"
}
