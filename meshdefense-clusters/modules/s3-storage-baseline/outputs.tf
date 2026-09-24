output "bucket_names" {
  value = {
    for k, v in aws_s3_bucket.this : k => v.id
  }
  description = "Map of created S3 bucket names"
}

output "bucket_arns" {
  value = {
    for k, v in aws_s3_bucket.this : k => v.arn
  }
  description = "Map of created S3 bucket ARNs"
}

output "harbor_bucket_name" {
  value       = aws_s3_bucket.this["harbor"].id
  description = "Bucket name for Harbor OCI container blobs"
}

output "velero_bucket_name" {
  value       = aws_s3_bucket.this["velero"].id
  description = "Bucket name for Velero cluster backups"
}

output "loki_bucket_name" {
  value       = aws_s3_bucket.this["loki"].id
  description = "Bucket name for Loki distributed log chunks"
}

output "audit_bucket_name" {
  value       = aws_s3_bucket.this["audit"].id
  description = "Bucket name for cluster audit traces"
}
