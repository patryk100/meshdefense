# AWS EKS IL6 Module (Air-Gapped & DISA STIG Compliant)

This module provisions an Amazon EKS cluster configured specifically for **DoD Impact Level 6 (IL6)**, AWS GovCloud, and AWS Secret / Top-Secret air-gapped enclaves.

## Air-Gap & IL6 Security Highlights
1. **Private Access Only**: Public API access is disabled (`endpoint_public_access = false`). Communication with the control plane is only possible via private VPC subnets or transit gateways.
2. **KMS Envelope Encryption**: All Kubernetes `Secrets` are encrypted at rest using an AWS KMS Customer Managed Key (CMK) with automated key rotation.
3. **Bottlerocket / AL2 STIG AMIs**: Uses hardened Bottlerocket or Amazon Linux 2 DISA STIG AMIs.
4. **Node Separation**: Segregates Core Big Bang platform workloads (Istio, Gatekeeper, Flux) onto dedicated `system` node pools, separate from tenant/app workloads (`workload` node pool).
5. **Full Audit Logging**: Control plane audit, API, authenticator, and controller logs enabled for SIEM ingestion.
