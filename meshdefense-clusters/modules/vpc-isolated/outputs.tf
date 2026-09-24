output "vpc_id" {
  value       = aws_vpc.this.id
  description = "The ID of the isolated VPC"
}

output "vpc_cidr" {
  value       = aws_vpc.this.cidr_block
  description = "The CIDR block of the isolated VPC"
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "List of IDs of the private subnets across AZs"
}

output "route_table_ids" {
  value       = aws_route_table.private[*].id
  description = "List of IDs of the private route tables"
}

output "flow_log_group_arn" {
  value       = aws_cloudwatch_log_group.flow_logs.arn
  description = "ARN of the CloudWatch log group for VPC Flow Logs"
}
