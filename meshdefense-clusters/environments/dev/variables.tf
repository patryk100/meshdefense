variable "region" {
  type    = string
  default = "us-gov-west-1"
}

variable "vpc_id" {
  type        = string
  description = "Target private VPC ID"
}

variable "vpc_cidr" {
  type    = string
  default = "10.100.0.0/16"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnets for nodes and endpoints"
}

variable "route_table_ids" {
  type        = list(string)
  description = "Route table IDs for S3 gateway endpoint"
}

variable "kubernetes_version" {
  type    = string
  default = "1.33"
}

variable "bastion_ami_id" {
  type        = string
  description = "Hardened AMI ID for bastion"
}
