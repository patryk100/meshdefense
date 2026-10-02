output "private_hosted_zone_id" {
  description = "Zone ID of the private Route53 zone"
  value       = aws_route53_zone.internal.zone_id
}

output "internal_domain" {
  description = "The internal domain name"
  value       = var.internal_domain
}

output "endpoint_security_group_id" {
  description = "Security group ID for VPC interface endpoints"
  value       = aws_security_group.vpc_endpoints.id
}

output "vpc_endpoint_ids" {
  description = "Map of all VPC interface endpoint IDs"
  value       = { for k, v in aws_vpc_endpoint.interface_endpoints : k => v.id }
}

output "s3_endpoint_id" {
  description = "ID of the S3 Gateway VPC endpoint"
  value       = aws_vpc_endpoint.s3.id
}

output "ingress_apps_wildcard_fqdn" {
  description = "Wildcard FQDN for platform apps under the internal domain"
  value       = "*.apps.${var.internal_domain}"
}

output "ingress_apex_fqdn" {
  description = "Apex FQDN of the private domain"
  value       = var.internal_domain
}
