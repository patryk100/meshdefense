terraform {
  required_version = ">= 1.5.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.26"
    }
  }
}

# --------------------------------------------------------------------------------------------------
# Dedicated Namespace for Harbor Registry
# --------------------------------------------------------------------------------------------------
resource "kubernetes_namespace" "harbor" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "harbor"
      "meshdefense.io/environment" = var.environment
      "istio-injection"            = "disabled" # Standalone during initial bootstrap
    }
  }
}

# --------------------------------------------------------------------------------------------------
# Harbor Helm Release (Air-Gapped Local OCI Registry)
# --------------------------------------------------------------------------------------------------
resource "helm_release" "harbor" {
  name      = "harbor"
  namespace = kubernetes_namespace.harbor.metadata[0].name
  chart     = var.harbor_chart_path
  version   = var.harbor_chart_version

  values = [
    yamlencode({
      expose = {
        type = "ClusterIP"
        tls = {
          enabled    = true
          secretName = var.tls_secret_name
        }
      }
      externalURL = "https://${var.registry_domain}"
      persistence = {
        enabled = true
        imageChartStorage = {
          type = var.storage_type # s3, azure, gcs, or filesystem
          s3 = var.storage_type == "s3" ? {
            bucket  = var.storage_bucket
            region  = var.storage_region
            encrypt = true
            secure  = true
          } : null
        }
      }
      trivy = {
        enabled     = true
        offlineMode = true # Air-gapped CVE scanning
      }
      notary = {
        enabled = false # Cosign preferred for Big Bang/Iron Bank
      }
    })
  ]
}
