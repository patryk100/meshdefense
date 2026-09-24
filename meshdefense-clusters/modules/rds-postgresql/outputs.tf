output "db_instance_id" {
  value       = aws_db_instance.this.id
  description = "The RDS DB instance ID"
}

output "db_instance_arn" {
  value       = aws_db_instance.this.arn
  description = "The ARN of the RDS DB instance"
}

output "db_endpoint" {
  value       = aws_db_instance.this.endpoint
  description = "The connection endpoint for PostgreSQL (hostname:port)"
}

output "db_address" {
  value       = aws_db_instance.this.address
  description = "The private DNS hostname of the PostgreSQL instance"
}

output "db_port" {
  value       = aws_db_instance.this.port
  description = "The port the database is listening on (5432)"
}

output "db_security_group_id" {
  value       = aws_security_group.rds.id
  description = "The security group ID attached to RDS"
}

output "db_subnet_group_name" {
  value       = aws_db_subnet_group.this.name
  description = "The name of the RDS subnet group"
}

output "db_parameter_group_name" {
  value       = aws_db_parameter_group.this.name
  description = "The parameter group enforcing TLS 1.2+"
}

output "db_credentials_secret_arn" {
  value       = aws_secretsmanager_secret.db_credentials.arn
  description = "The ARN of the AWS Secrets Manager secret storing master credentials"
}

output "db_credentials_secret_name" {
  value       = aws_secretsmanager_secret.db_credentials.name
  description = "The name of the AWS Secrets Manager secret"
}
