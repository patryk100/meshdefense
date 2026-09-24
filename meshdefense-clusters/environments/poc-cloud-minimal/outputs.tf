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

output "kms_k8s_secrets_key_arn" {
  value       = module.kms_keyring.k8s_secrets_key_arn
  description = "KMS Key ARN for Kubernetes Secrets Envelope Encryption"
}

output "kms_ebs_key_arn" {
  value       = module.kms_keyring.ebs_key_arn
  description = "KMS Key ARN for EBS Storage Encryption"
}

output "kms_s3_key_arn" {
  value       = module.kms_keyring.s3_key_arn
  description = "KMS Key ARN for S3 Object Encryption"
}

output "kms_rds_key_arn" {
  value       = module.kms_keyring.rds_key_arn
  description = "KMS Key ARN for RDS Database Encryption"
}

output "kms_secrets_key_arn" {
  value       = module.kms_keyring.secrets_key_arn
  description = "KMS Key ARN for Secrets Manager Encryption"
}

output "all_kms_key_arns" {
  value = merge(
    { network = module.kms_network.key_arn },
    module.kms_keyring.all_key_arns
  )
  description = "Map of all 6 dedicated cryptographic domain KMS key ARNs"
}

output "bastion_instance_id" {
  value       = try(module.bastion[0].bastion_instance_id, null)
  description = "EC2 instance ID for Day-0 ephemeral bastion"
}

output "bastion_private_ip" {
  value       = try(module.bastion[0].bastion_private_ip, null)
  description = "Private IP address of the Day-0 bastion"
}

output "bastion_security_group_id" {
  value       = try(module.bastion[0].bastion_security_group_id, null)
  description = "Security group ID of the Day-0 bastion (zero ingress)"
}

output "bastion_ssm_connect_command" {
  value       = try(module.bastion[0].ssm_connect_command, null)
  description = "AWS CLI SSM Session Manager connect command"
}

output "bastion_ssm_logs_cloudwatch" {
  value       = try(module.bastion[0].cloudwatch_log_group_name, null)
  description = "CloudWatch log group recording encrypted SSM sessions"
}

output "bastion_ssm_logs_s3" {
  value       = try(module.bastion[0].s3_bucket_name, null)
  description = "S3 bucket recording encrypted SSM sessions"
}


