terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# --------------------------------------------------------------------------------------------------
# User-Assigned Managed Identity for AKS Control Plane & Kubelet
# --------------------------------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "aks" {
  name                = "${var.cluster_name}-aks-identity"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# --------------------------------------------------------------------------------------------------
# Azure AKS Private Cluster (IL6 Government Secret Configuration)
# --------------------------------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster" "this" {
  name                    = var.cluster_name
  location                = var.location
  resource_group_name     = var.resource_group_name
  dns_prefix_private_cluster = "${var.cluster_name}-priv"
  kubernetes_version      = var.kubernetes_version
  private_cluster_enabled = true # CRITICAL FOR AIRGAP / IL6 ENCLAVES

  # System Pool (Core Big Bang components: Flux, Istio, OPA/Gatekeeper)
  default_node_pool {
    name                = "systempool"
    vm_size             = var.system_vm_size
    node_count          = var.system_node_count
    enable_auto_scaling = true
    min_count           = var.system_min_count
    max_count           = var.system_max_count
    vnet_subnet_id      = var.subnet_id
    os_disk_type        = "Managed"
    os_disk_size_gb     = 128
    fips_enabled        = true # Required for DoD IL6 compliance

    node_labels = {
      "node.meshdefense.io/role" = "system"
      "platformone.dso.mil/tier" = "core"
    }

    tags = var.tags
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  tags = merge(var.tags, {
    "meshdefense.io/environment" = var.environment
  })
}

# --------------------------------------------------------------------------------------------------
# Workload Node Pool for Big Bang Applications (GitLab, SonarQube, Monitoring)
# --------------------------------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster_node_pool" "workload" {
  name                  = "workloadpool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.workload_vm_size
  node_count            = var.workload_node_count
  enable_auto_scaling   = true
  min_count             = var.workload_min_count
  max_count             = var.workload_max_count
  vnet_subnet_id        = var.subnet_id
  os_disk_type          = "Managed"
  os_disk_size_gb       = 256
  fips_enabled          = true

  node_labels = {
    "node.meshdefense.io/role" = "workload"
    "platformone.dso.mil/tier" = "apps"
  }

  tags = var.tags
}
