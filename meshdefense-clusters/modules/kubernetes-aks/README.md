# Azure AKS IL6 Module (Air-Gapped & FIPS Compliant)

This module provisions an Azure Kubernetes Service (AKS) private cluster configured for **Azure Government Secret (DoD IL6)** and disconnected defense environments.

## Air-Gap & IL6 Security Highlights
1. **Private Cluster**: Control plane API server is completely isolated with no public IP exposure (`private_cluster_enabled = true`). Access occurs via Azure Private Link and private DNS zones.
2. **FIPS 140-2 Enabled Nodes**: Enforces FIPS cryptographic compliance across Linux worker nodes (`fips_enabled = true`).
3. **Key Vault CSI Driver**: Integrated with Azure Key Vault via Managed Identity for secret rotation and envelope encryption.
4. **Node Pool Separation**: Separates core Big Bang infrastructure (`systempool`) from heavy DevSecOps workloads (`workloadpool`).
