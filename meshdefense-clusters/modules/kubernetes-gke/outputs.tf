output "cluster_id" {
  description = "Cluster ID"
  value       = google_container_cluster.this.id
}

output "cluster_name" {
  description = "Cluster Name"
  value       = google_container_cluster.this.name
}

output "endpoint" {
  description = "Private cluster endpoint"
  value       = google_container_cluster.this.endpoint
}

output "ca_certificate" {
  description = "Cluster CA certificate"
  value       = google_container_cluster.this.master_auth[0].cluster_ca_certificate
}
