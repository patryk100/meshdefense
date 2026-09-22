output "bastion_instance_id" {
  description = "EC2 Instance ID of the bastion"
  value       = aws_instance.bastion.id
}

output "bastion_private_ip" {
  description = "Private IP of the bastion"
  value       = aws_instance.bastion.private_ip
}
