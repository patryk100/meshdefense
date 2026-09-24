output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "The ID of the isolated VPC"
}

output "vpc_cidr" {
  value       = module.vpc.vpc_cidr
  description = "The CIDR block of the isolated VPC"
}

output "private_subnet_ids" {
  value       = module.vpc.private_subnet_ids
  description = "List of private subnet IDs"
}

output "route_table_ids" {
  value       = module.vpc.route_table_ids
  description = "List of private route table IDs"
}

output "kms_network_key_arn" {
  value       = module.kms_network.key_arn
  description = "KMS Key ARN for network and flow log encryption"
}

output "kms_network_alias" {
  value       = module.kms_network.alias_name
  description = "KMS Alias for network key"
}

output "flow_log_group_arn" {
  value       = module.vpc.flow_log_group_arn
  description = "CloudWatch log group ARN for VPC flow logs"
}

output "vpc_endpoints_security_group_id" {
  value       = module.networking.endpoint_security_group_id
  description = "Security group ID for VPC Interface Endpoints"
}

output "route53_zone_id" {
  value       = module.networking.private_hosted_zone_id
  description = "Private Hosted Zone ID for internal DNS"
}
