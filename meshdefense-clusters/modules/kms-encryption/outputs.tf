output "key_arn" {
  value       = aws_kms_key.this.arn
  description = "The Amazon Resource Name (ARN) of the KMS key"
}

output "key_id" {
  value       = aws_kms_key.this.key_id
  description = "The globally unique identifier for the KMS key"
}

output "alias_arn" {
  value       = aws_kms_alias.this.arn
  description = "The ARN of the KMS key alias"
}

output "alias_name" {
  value       = aws_kms_alias.this.name
  description = "The name of the KMS key alias"
}
