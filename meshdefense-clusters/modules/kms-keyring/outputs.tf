output "k8s_secrets_key_arn" {
  value       = module.k8s_secrets_key.key_arn
  description = "KMS Key ARN for Kubernetes secrets envelope encryption"
}

output "k8s_secrets_key_id" {
  value       = module.k8s_secrets_key.key_id
  description = "KMS Key ID for Kubernetes secrets envelope encryption"
}

output "k8s_secrets_alias" {
  value       = module.k8s_secrets_key.alias_name
  description = "KMS Alias for Kubernetes secrets envelope encryption"
}

output "ebs_key_arn" {
  value       = module.ebs_key.key_arn
  description = "KMS Key ARN for EBS volume encryption"
}

output "ebs_key_id" {
  value       = module.ebs_key.key_id
  description = "KMS Key ID for EBS volume encryption"
}

output "ebs_alias" {
  value       = module.ebs_key.alias_name
  description = "KMS Alias for EBS volume encryption"
}

output "s3_key_arn" {
  value       = module.s3_key.key_arn
  description = "KMS Key ARN for S3 object encryption"
}

output "s3_key_id" {
  value       = module.s3_key.key_id
  description = "KMS Key ID for S3 object encryption"
}

output "s3_alias" {
  value       = module.s3_key.alias_name
  description = "KMS Alias for S3 object encryption"
}

output "rds_key_arn" {
  value       = module.rds_key.key_arn
  description = "KMS Key ARN for RDS database encryption"
}

output "rds_key_id" {
  value       = module.rds_key.key_id
  description = "KMS Key ID for RDS database encryption"
}

output "rds_alias" {
  value       = module.rds_key.alias_name
  description = "KMS Alias for RDS database encryption"
}

output "secrets_key_arn" {
  value       = module.secrets_key.key_arn
  description = "KMS Key ARN for Secrets Manager encryption"
}

output "secrets_key_id" {
  value       = module.secrets_key.key_id
  description = "KMS Key ID for Secrets Manager encryption"
}

output "secrets_alias" {
  value       = module.secrets_key.alias_name
  description = "KMS Alias for Secrets Manager encryption"
}

output "all_key_arns" {
  value = {
    k8s_secrets = module.k8s_secrets_key.key_arn
    ebs         = module.ebs_key.key_arn
    s3          = module.s3_key.key_arn
    rds         = module.rds_key.key_arn
    secrets     = module.secrets_key.key_arn
  }
  description = "Map of all tier KMS key ARNs in the keyring"
}
