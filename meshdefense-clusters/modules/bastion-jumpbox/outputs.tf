output "bastion_instance_id" {
  value       = aws_instance.bastion.id
  description = "The ID of the bastion EC2 instance"
}

output "bastion_private_ip" {
  value       = aws_instance.bastion.private_ip
  description = "The private IP address of the bastion"
}

output "bastion_security_group_id" {
  value       = aws_security_group.bastion.id
  description = "The security group ID attached to the bastion (zero ingress)"
}

output "bastion_iam_role_arn" {
  value       = aws_iam_role.bastion.arn
  description = "The ARN of the IAM role assumed by the bastion"
}

output "cloudwatch_log_group_name" {
  value       = aws_cloudwatch_log_group.ssm_sessions.name
  description = "CloudWatch log group recording encrypted SSM sessions"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.ssm_sessions.id
  description = "S3 bucket name recording encrypted SSM sessions"
}

output "ssm_connect_command" {
  value       = "aws ssm start-session --target ${aws_instance.bastion.id}"
  description = "AWS CLI command to connect to the bastion via SSM Session Manager"
}
