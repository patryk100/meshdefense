# GCP GKE IL6 Module (Air-Gapped & Shielded)

This module provisions a private Google Kubernetes Engine (GKE) cluster in Google Cloud for Government / Google Distributed Cloud Hosted (GDCH) for **DoD Impact Level 6 (IL6)** environments.

## Air-Gap & IL6 Security Highlights
1. **Fully Private Cluster**: Master endpoint and worker nodes are strictly internal without public IP addresses (`enable_private_endpoint = true`, `enable_private_nodes = true`).
2. **CMEK etcd Encryption**: Customer-managed KMS keys used for etcd database encryption (`database_encryption`).
3. **Shielded Nodes**: Secure Boot, virtual TPM, and integrity monitoring are enabled on all node pools.
4. **Calico Network Policies**: Zero-trust pod-to-pod network policy enforcement.
5. **Workload Pools**: Dedicated system pool for Big Bang core controllers and workload pool for DevSecOps applications.
