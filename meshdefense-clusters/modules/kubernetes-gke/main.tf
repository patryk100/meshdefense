terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# --------------------------------------------------------------------------------------------------
# Service Account for GKE Nodes
# --------------------------------------------------------------------------------------------------
resource "google_service_account" "gke_nodes" {
  account_id   = "${var.cluster_name}-gke-nodes"
  display_name = "GKE Node Service Account for ${var.cluster_name}"
}

resource "google_project_iam_member" "node_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "node_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# --------------------------------------------------------------------------------------------------
# GKE Private Cluster (Google Distributed Cloud Hosted / IL6 Compliant)
# --------------------------------------------------------------------------------------------------
resource "google_container_cluster" "this" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  network    = var.network
  subnetwork = var.subnetwork

  # Remove default node pool after creation to enforce custom pools
  remove_default_node_pool = true
  initial_node_count       = 1

  # Strict Private Cluster Configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true # Control plane accessible only from internal VPC
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.authorized_cidr_blocks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  # Hardening & Security
  release_channel {
    channel = "STABLE"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  database_encryption {
    state    = "ENCRYPTED"
    key_name = var.kms_key_name
  }

  resource_labels = merge(var.labels, {
    "environment" = var.environment
  })
}

# --------------------------------------------------------------------------------------------------
# System Node Pool (Core Big Bang components: Istio, Gatekeeper, Flux)
# --------------------------------------------------------------------------------------------------
resource "google_container_node_pool" "system" {
  name       = "system-pool"
  location   = var.region
  cluster    = google_container_cluster.this.name
  node_count = var.system_node_count
  project    = var.project_id

  node_config {
    machine_type    = var.system_machine_type
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    image_type = "COS_CONTAINERD"

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = {
      "node.meshdefense.io/role" = "system"
      "platformone.dso.mil/tier" = "core"
    }

    tags = ["gke-node", "${var.cluster_name}-node"]
  }
}

# --------------------------------------------------------------------------------------------------
# Workload Node Pool (Big Bang Addons & App Workloads)
# --------------------------------------------------------------------------------------------------
resource "google_container_node_pool" "workload" {
  name       = "workload-pool"
  location   = var.region
  cluster    = google_container_cluster.this.name
  node_count = var.workload_node_count
  project    = var.project_id

  node_config {
    machine_type    = var.workload_machine_type
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    image_type = "COS_CONTAINERD"

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = {
      "node.meshdefense.io/role" = "workload"
      "platformone.dso.mil/tier" = "apps"
    }

    tags = ["gke-node", "${var.cluster_name}-node"]
  }
}
