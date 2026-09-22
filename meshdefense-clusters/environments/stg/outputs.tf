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
