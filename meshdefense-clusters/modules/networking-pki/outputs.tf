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
