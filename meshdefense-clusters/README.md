# meshdefense-clusters (Infrastructure as Code)

This repository contains the Terraform and Infrastructure as Code (IaC) modules for provisioning air-gapped, STIG-compliant Kubernetes clusters capable of hosting Platform One's **Big Bang** across common cloud Kubernetes offerings supporting **DoD Impact Level 6 (IL6)** and Secret/Top-Secret cloud regions:

- **AWS EKS** (AWS GovCloud / AWS Secret Region / Commercial Cloud Services IL6)
- **Azure AKS** (Azure Government Secret IL6)
- **GCP GKE** (Google Distributed Cloud Hosted / Google Cloud for Government IL6)

In addition to the managed Kubernetes control planes, this repository provisions the air-gap foundational infrastructure:
- **Private Container Registry (Harbor)** backed by secure object storage (S3/Azure Blob/GCS).
- **Zero-Trust Private Networking & VPC Endpoints** for strictly isolated environments with no outbound internet access.
- **Air-Gap Transfer Bastion / Staging Node** equipped with container mirroring tools (Skopeo, Helm, Cosign, Flux CLI).

---

## Directory Layout

```
meshdefense-clusters/
├── modules/
│   ├── kubernetes-eks/       # AWS EKS IL6 (Private cluster, KMS envelope encryption, Bottlerocket/AL2 STIG)
│   ├── kubernetes-aks/       # Azure AKS IL6 (Private cluster, FIPS 140-2, Azure Key Vault CSI)
│   ├── kubernetes-gke/       # GCP GKE IL6 (Private cluster, Shielded nodes, CMEK)
│   ├── airgap-registry/      # Harbor OCI Registry on private object storage
│   ├── networking-pki/       # Private DNS, internal CA PKI, VPC endpoints
│   └── bastion-jumpbox/      # Secure staging bastion with Skopeo, Cosign, Helm
├── environments/
│   ├── dev/                  # Development cluster (lightweight node pools, single AZ)
│   ├── test/                 # Testing / integration cluster
│   ├── stg/                  # Staging cluster (production parity, multi-AZ)
│   └── prod/                 # Production cluster (strict multi-AZ HA, dedicated system/infra/app pools)
└── scripts/
    ├── airgap-prereqs.sh     # Pre-flight check for IAM, KMS, VPC CIDRs, and air-gap connectivity
    └── airgap-cluster-bootstrap.sh # Post-creation script for CA certificates & Flux v2 CRD pre-installation
```

---

## Supported Cloud IL6 Kubernetes Architecture

### 1. AWS EKS in IL6
- **Endpoint Access**: Private access ONLY (`endpoint_private_access = true`, `endpoint_public_access = false`).
- **Secrets Encryption**: AWS KMS Envelope Encryption using dedicated customer managed key (CMK).
- **Node OS**: Bottlerocket CIS Benchmark AMI or Amazon Linux 2 DISA STIG AMI.
- **Networking**: AWS VPC CNI with private subnets, security groups enforcing zero egress except to configured VPC Endpoints.

### 2. Azure AKS in IL6
- **Private Cluster**: API server exposed only via Private Endpoint on isolated VNet.
- **FIPS 140-2**: Enabled on all worker node pools (`fips_enabled = true`).
- **Identity & Secrets**: Managed Identities with Azure Key Vault Secrets Store CSI Driver.

### 3. GCP GKE in IL6 / GDCH
- **Private Cluster**: Private nodes and private control plane endpoint.
- **Shielded GKE Nodes**: Secure Boot and integrity monitoring enabled by default.
- **CMEK**: Customer-managed encryption keys for control plane etcd and persistent storage disks.

---

## Deployment Quickstart

1. Choose your environment target:
   ```bash
   cd environments/dev
   ```
2. Copy and configure variables:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit cloud provider credentials, VPC IDs, and cluster sizing
   ```
3. Run pre-flight check:
   ```bash
   ../../scripts/airgap-prereqs.sh
   ```
4. Initialize and apply Terraform:
   ```bash
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```
5. Bootstrap cluster with internal certificates:
   ```bash
   ../../scripts/airgap-cluster-bootstrap.sh
   ```
