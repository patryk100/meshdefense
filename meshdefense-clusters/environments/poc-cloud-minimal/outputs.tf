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

output "s3_storage_buckets" {
  value       = module.s3_storage.bucket_names
  description = "Map of all provisioned air-gapped S3 workload buckets"
}

output "s3_harbor_bucket" {
  value       = module.s3_storage.harbor_bucket_name
  description = "S3 bucket for Harbor OCI container blobs"
}

output "s3_velero_bucket" {
  value       = module.s3_storage.velero_bucket_name
  description = "S3 bucket for Velero cluster backups"
}

output "s3_loki_bucket" {
  value       = module.s3_storage.loki_bucket_name
  description = "S3 bucket for Loki log chunks"
}

output "s3_audit_bucket" {
  value       = module.s3_storage.audit_bucket_name
  description = "S3 bucket for cluster audit traces"
}

output "rds_endpoint" {
  value       = try(module.rds[0].db_endpoint, null)
  description = "Connection endpoint for PostgreSQL (hostname:port)"
}

output "rds_address" {
  value       = try(module.rds[0].db_address, null)
  description = "Private DNS hostname of the PostgreSQL instance"
}

output "rds_security_group_id" {
  value       = try(module.rds[0].db_security_group_id, null)
  description = "Security group ID attached to RDS"
}

output "rds_credentials_secret_name" {
  value       = try(module.rds[0].db_credentials_secret_name, null)
  description = "Secrets Manager secret name containing master credentials"
}

output "eks_cluster_name" {
  value       = try(module.kubernetes[0].cluster_name, null)
  description = "EKS cluster name"
}

output "eks_cluster_endpoint" {
  value       = try(module.kubernetes[0].cluster_endpoint, null)
  description = "EKS private API server endpoint"
}

output "eks_oidc_provider_arn" {
  value       = try(module.kubernetes[0].oidc_provider_arn, null)
  description = "EKS OIDC provider ARN for IRSA"
}

output "eks_node_launch_template_id" {
  value       = try(module.kubernetes[0].launch_template_id, null)
  description = "Hardened EC2 launch template ID enforcing IMDSv2 and EBS CMK encryption"
}

output "karpenter_controller_role_arn" {
  value       = try(module.kubernetes[0].karpenter_controller_role_arn, null)
  description = "IAM Role ARN for Karpenter Controller"
}

output "karpenter_node_role_arn" {
  value       = try(module.kubernetes[0].karpenter_node_role_arn, null)
  description = "IAM Role ARN for Karpenter provisioned nodes"
}

output "karpenter_interruption_queue_url" {
  value       = try(module.kubernetes[0].karpenter_interruption_queue_url, null)
  description = "SQS Queue URL for Karpenter interruption handling"
}





