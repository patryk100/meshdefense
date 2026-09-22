variable "region" {
  type    = string
  default = "us-gov-west-1"
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.104.0.0/16"
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "route_table_ids" {
  type = list(string)
}

variable "kubernetes_version" {
  type    = string
  default = "1.30"
}
