variable "environment" {
  type        = string
}

variable "ami_id" {
  type        = string
  description = "AMI ID (RHEL / AL2 DISA STIG hardened AMI)"
}

variable "instance_type" {
  type        = string
  default     = "m6i.xlarge"
}

variable "subnet_id" {
  type        = string
}

variable "vpc_id" {
  type        = string
}

variable "vpc_cidr" {
  type        = string
}

variable "kms_key_arn" {
  type        = string
  description = "KMS CMK ARN for EBS encryption"
}

variable "tags" {
  type        = map(string)
  default     = {}
}
