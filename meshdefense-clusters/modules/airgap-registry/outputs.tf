output "registry_url" {
  description = "URL of the internal container registry"
  value       = "https://${var.registry_domain}"
}

output "namespace" {
  description = "Namespace where Harbor is deployed"
  value       = kubernetes_namespace.harbor.metadata[0].name
}
