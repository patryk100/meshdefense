output "repository_arns" {
  description = "Map of all provisioned ECR repository names to their ARNs"
  value = {
    for k, v in aws_ecr_repository.bootstrap : k => v.arn
  }
}

output "repository_urls" {
  description = "Map of all provisioned ECR repository names to their repository URLs"
  value = {
    for k, v in aws_ecr_repository.bootstrap : k => v.repository_url
  }
}

output "repository_registry_ids" {
  description = "Registry IDs for the provisioned repositories"
  value = {
    for k, v in aws_ecr_repository.bootstrap : k => v.registry_id
  }
}
