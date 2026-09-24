variable "environment" {
  type        = string
  description = "Environment identifier (e.g., poc-minimal, dev, prod)"
}

variable "ami_id" {
  type        = string
  default     = null
  description = "Optional AMI ID (e.g. DISA STIG hardened AMI). If null, latest Amazon Linux 2023 is looked up."
}

variable "instance_type" {
  type        = string
  default     = "t3.small"
  description = "EC2 instance type for administrative bastion"
}

variable "subnet_id" {
  type        = string
  description = "Private management subnet ID where the bastion is placed"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the bastion is hosted"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block for internal routing"
}

variable "ebs_kms_key_arn" {
  type        = string
  description = "KMS Customer Managed Key ARN for EBS volume encryption"
}

variable "s3_kms_key_arn" {
  type        = string
  description = "KMS Customer Managed Key ARN for S3 session log encryption"
}

variable "logs_kms_key_arn" {
  type        = string
  description = "KMS Customer Managed Key ARN for CloudWatch session log encryption"
}

variable "root_volume_size" {
  type        = number
  default     = 50
  description = "Size of root volume in GB (cost-conscious default for minimal, can scale to 200 for Big Bang)"
}

variable "bootstrap_s3_bucket_arns" {
  type        = list(string)
  default     = []
  description = "Optional list of S3 bucket ARNs containing bootstrap binaries, charts, and diode packages"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags"
}
