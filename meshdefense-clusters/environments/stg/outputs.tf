output "cluster_id" {
  value = module.kubernetes.cluster_id
}

output "cluster_endpoint" {
  value = module.kubernetes.cluster_endpoint
}

output "private_dns_zone" {
  value = module.networking.internal_domain
}

output "bastion_ip" {
  value = module.bastion.bastion_private_ip
}

output "kms_key_arns" {
  value       = module.kms_keyring.all_key_arns
  description = "Map of all multi-tier KMS key ARNs for stg environment"
}

output "s3_storage_buckets" {
  value       = module.s3_storage.bucket_names
  description = "Map of all S3 storage buckets in stg environment"
}

output "rds_endpoint" {
  value       = module.rds.db_endpoint
  description = "PostgreSQL connection endpoint in stg environment"
}

output "rds_security_group_id" {
  value       = module.rds.db_security_group_id
  description = "Security group ID for RDS PostgreSQL in stg"
}

output "vpc_endpoint_ids" {
  value       = module.networking.vpc_endpoint_ids
  description = "Map of all VPC interface endpoint IDs"
}

output "vpc_s3_endpoint_id" {
  value       = module.networking.s3_endpoint_id
  description = "ID of the S3 Gateway VPC endpoint"
}

output "irsa_role_arns" {
  value       = module.irsa_factory.role_arns
  description = "Map of all provisioned IRSA IAM Role ARNs"
}

output "irsa_service_account_annotations" {
  value       = module.irsa_factory.service_account_annotations
  description = "Map of ServiceAccount annotations (eks.amazonaws.com/role-arn) ready for Helm/K8s manifests"
}

output "irsa_aws_load_balancer_controller_role_arn" {
  value       = module.irsa_factory.aws_load_balancer_controller_role_arn
  description = "IAM Role ARN for AWS Load Balancer Controller"
}
