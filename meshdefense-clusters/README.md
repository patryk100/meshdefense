# meshdefense-clusters (Infrastructure as Code & Cloud Enclave Engine)

The `meshdefense-clusters` repository provides modular, STIG-compliant Terraform Infrastructure as Code (IaC) modules and declarative Kubernetes manifests designed to provision and operate air-gapped Kubernetes enclaves.

It targets classified, disconnected defense environments across:
- **AWS EKS**: AWS GovCloud, AWS Secret Region, and Commercial Cloud Services (DoD IL6 / ISOB)
- **Azure AKS**: Azure Government Secret (DoD IL6)
- **GCP GKE**: Google Distributed Cloud Hosted / Google Cloud for Government

---

## 📁 Repository Structure & Contents

```
meshdefense-clusters/
├── modules/
│   ├── vpc-isolated/         # Isolated Multi-AZ VPC (zero default IGWs, private subnets, VPC Endpoints)
│   ├── kms-keyring/          # Dedicated 6-CMK cryptographic domain keyring (automated annual rotation)
│   ├── bastion-jumpbox/      # Ephemeral SSM-only administrative jumpbox with S3/CW session audit logging
│   ├── s3-storage-baseline/  # Hardened S3 object storage buckets with SSE-KMS and TLS 1.2+ enforcement
│   ├── rds-postgresql/       # Multi-AZ RDS PostgreSQL with SSL enforcement and IAM authentication
│   ├── kubernetes-eks/       # Private EKS control plane, IMDSv2 enforcement, and Chrony time sync
│   ├── irsa-factory/         # Automated least-privilege IAM Roles for Service Accounts (IRSA)
│   ├── airgap-registry/      # Day-0 bootstrap ECR container repositories with KMS encryption
│   ├── networking-pki/       # Private Route 53 DNS and internal PKI interface endpoints
│   ├── kubernetes-aks/       # Azure AKS government baseline (FIPS 140-2)
│   └── kubernetes-gke/       # GCP GKE government baseline (Shielded nodes, CMEK)
├── environments/
│   ├── poc-cloud-minimal/    # Cost-effective, minimal single-node cloud testing environment
│   ├── dev/                  # Development enclave
│   ├── test/                 # Integration test enclave
│   ├── stg/                  # Staging enclave (production parity)
│   └── prod/                 # Full production enclave (Multi-AZ HA, strict audit logging)
├── manifests/
│   ├── aws-load-balancer-controller/ # AWS Load Balancer Controller and internal NLB manifests
│   ├── cato-oscal-exporter/          # Automated OSCAL compliance exporter CronJob
│   ├── external-secrets/             # External Secrets Operator and AWS Secrets Manager stores
│   ├── flux-system/                  # Flux v2 GitOps controllers and OCI reconciliation
│   ├── harbor/                       # In-cluster Harbor registry with S3 backend
│   ├── istio-core/                   # Istio CRDs, STRICT mTLS PeerAuthentication, and Ingress
│   ├── keycloak/                     # Keycloak DoD SSO and database configuration
│   ├── kyverno/                      # Kyverno admission controller, NIST policy pack, and event streamer
│   ├── monitoring/                   # LGTM stack (Loki S3, Prometheus M-21-31, Tempo, Grafana cATO dashboard)
│   ├── neuvector/                    # NeuVector Active Cyber Defense DaemonSet (Protect mode)
│   ├── smoke-tests/                  # Automated pre-flight and post-upgrade smoke test Jobs
│   ├── vault/                        # HashiCorp Vault with Raft storage and AWS KMS auto-unseal
│   ├── vector/                       # Vector OCSF telemetry shipper DaemonSet
│   └── velero/                       # Velero backup & DR with S3/KMS and EBS snapshotting
└── scripts/                          # Turnkey deployment scripts and lifecycle CLIs
```

---

## 🛠 Operational Scripts Reference

The `scripts/` directory houses deployment automation and verification tools:

| Script | Purpose & Function |
| :--- | :--- |
| [`meshdefense-env.sh`](scripts/meshdefense-env.sh) | Enclave discovery helper dynamically resolving AWS Account ID, Region, Partition, and Cluster metadata. |
| [`seed-ecr-bootstrap.sh`](scripts/seed-ecr-bootstrap.sh) | Pre-seeds bootstrap images (Flux, CoreDNS, VPC CNI, Harbor) into private ECR repositories. |
| [`deploy-aws-load-balancer-controller.sh`](scripts/deploy-aws-load-balancer-controller.sh) | Deploys AWS Load Balancer Controller with IRSA for internal private NLB provisioning. |
| [`deploy-external-secrets.sh`](scripts/deploy-external-secrets.sh) | Installs External Secrets Operator and binds `ClusterSecretStore` to AWS Secrets Manager. |
| [`deploy-flux-bootstrap.sh`](scripts/deploy-flux-bootstrap.sh) | Bootstraps Flux v2 controllers pulling from private OCI image and chart repositories. |
| [`deploy-hardened-harbor.sh`](scripts/deploy-hardened-harbor.sh) | Deploys Harbor with S3/KMS storage, Keycloak OIDC, and Kyverno Cosign verification gates. |
| [`deploy-istio-zero-trust.sh`](scripts/deploy-istio-zero-trust.sh) | Enforces Istio service mesh in STRICT mTLS mode with egress lockdown. |
| [`deploy-vault-kms-raft.sh`](scripts/deploy-vault-kms-raft.sh) | Provisions HashiCorp Vault with Integrated Raft storage and AWS KMS auto-unseal. |
| [`deploy-keycloak-sso.sh`](scripts/deploy-keycloak-sso.sh) | Configures Keycloak DoD PKI/CAC authentication, realm imports, and external RDS persistence. |
| [`deploy-kyverno-policy-pack.sh`](scripts/deploy-kyverno-policy-pack.sh) | Deploys Kyverno admission controller with the NIST SP 800-53 Rev 5 policy pack. |
| [`deploy-neuvector-acd.sh`](scripts/deploy-neuvector-acd.sh) | Deploys NeuVector DaemonSet in `Protect` mode with behavioral eBPF network filtering. |
| [`deploy-oscal-exporter.sh`](scripts/deploy-oscal-exporter.sh) | Installs scheduled OSCAL exporter generating machine-readable compliance artifacts for eMASS. |
| [`deploy-velero-dr.sh`](scripts/deploy-velero-dr.sh) | Configures Velero backup engine with IRSA, encrypted S3 buckets, and daily EBS snapshots. |
| [`run-smoke-tests.sh`](scripts/run-smoke-tests.sh) | Ephemeral integration test Job validating mTLS, ingress routing, secret decryption, and storage mounts. |
| [`ironbank-cve-triage.py`](scripts/ironbank-cve-triage.py) | Scans tenant workloads for vulnerabilities, tracks MTTR against the DoD 14-day SLA, and applies tag patches. |
| [`dr-restore-drill.sh`](scripts/dr-restore-drill.sh) | Executes automated cross-region DR restoration drills, rehydrating RDS and Velero snapshots. |

---

## 🚀 How to Use & Deploy

### Step 1: Initialize Cloud Enclave Infrastructure
```bash
# Navigate to the chosen environment directory (e.g., poc-cloud-minimal or dev)
cd meshdefense-clusters/environments/poc-cloud-minimal

# Initialize Terraform providers
terraform init

# Review and execute infrastructure provisioning
terraform plan -out=tfplan
terraform apply tfplan
```

### Step 2: Connect to EKS Cluster
```bash
aws eks update-kubeconfig \
  --region $(terraform output -raw region 2>/dev/null || echo "us-east-1") \
  --name $(terraform output -raw eks_cluster_name)
```

### Step 3: Deploy Platform Components
Execute the deployment scripts in sequence:
```bash
# Core Controllers & Secrets
bash meshdefense-clusters/scripts/deploy-external-secrets.sh
bash meshdefense-clusters/scripts/deploy-vault-kms-raft.sh

# Zero-Trust Mesh & Identity
bash meshdefense-clusters/scripts/deploy-istio-zero-trust.sh
bash meshdefense-clusters/scripts/deploy-keycloak-sso.sh

# Security & Compliance Gates
bash meshdefense-clusters/scripts/deploy-kyverno-policy-pack.sh
bash meshdefense-clusters/scripts/deploy-neuvector-acd.sh
bash meshdefense-clusters/scripts/deploy-velero-dr.sh
```

### Step 4: Validate Enclave Health
```bash
# Run automated pre-flight smoke tests
bash meshdefense-clusters/scripts/run-smoke-tests.sh pre-flight
```
