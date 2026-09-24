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
  description = "Map of all multi-tier KMS key ARNs for dev environment"
}

