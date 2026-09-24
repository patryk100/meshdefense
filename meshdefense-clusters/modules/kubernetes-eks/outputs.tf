output "cluster_id" {
  description = "The name / ID of the EKS cluster"
  value       = aws_eks_cluster.this.id
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "The private endpoint URL of the EKS API server"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "The base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster control plane"
  value       = aws_security_group.cluster.id
}

output "kms_key_arn" {
  description = "ARN of the KMS CMK used for secret encryption"
  value       = local.kms_key_arn
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for IRSA"
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC Provider for IRSA"
  value       = aws_iam_openid_connect_provider.this.url
}

output "node_role_arn" {
  description = "IAM Role ARN for EKS worker nodes"
  value       = aws_iam_role.node_group.arn
}

output "launch_template_id" {
  description = "ID of the hardened EC2 launch template enforcing IMDSv2 and EBS CMK encryption"
  value       = aws_launch_template.hardened_node.id
}

output "karpenter_controller_role_arn" {
  description = "IAM Role ARN for Karpenter Controller IRSA"
  value       = try(aws_iam_role.karpenter_controller[0].arn, null)
}

output "karpenter_node_role_arn" {
  description = "IAM Role ARN for Karpenter-provisioned worker nodes"
  value       = try(aws_iam_role.karpenter_node[0].arn, null)
}

output "karpenter_instance_profile_name" {
  description = "Instance profile name for Karpenter-provisioned worker nodes"
  value       = try(aws_iam_instance_profile.karpenter_node[0].name, null)
}

output "karpenter_interruption_queue_url" {
  description = "SQS Queue URL for Karpenter interruption handling"
  value       = try(aws_sqs_queue.karpenter_interruption[0].url, null)
}
