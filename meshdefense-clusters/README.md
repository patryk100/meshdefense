# meshdefense-clusters (Infrastructure as Code & Cloud Enclave Engine)

This repository contains the Terraform Infrastructure as Code (IaC) modules and environment blueprints for provisioning air-gapped, STIG-compliant cloud Kubernetes enclaves capable of hosting Platform One's **Big Bang** across **DoD Impact Level 6 (IL6)** and Secret/Top-Secret cloud regions:

- **AWS EKS** (AWS GovCloud / AWS Secret Region / Commercial Cloud Services IL6)
- **Azure AKS** (Azure Government Secret IL6)
- **GCP GKE** (Google Distributed Cloud Hosted / Google Cloud for Government IL6)

---

## 🏛 Module Architecture & Capability Map

```
meshdefense-clusters/
├── modules/
│   ├── vpc-isolated/         # Story 1.1: Multi-AZ private VPC, zero IGW, VPC Endpoints (SC-7)
│   ├── kms-keyring/          # Story 1.2: 6 dedicated cryptographic domain CMKs (SC-12, SC-13)
│   ├── bastion-jumpbox/      # Story 1.3: SSM Session Manager bastion with S3/CW audit logging (AC-3)
│   ├── s3-storage-baseline/  # Story 1.4: Air-gapped S3 buckets with SSE-KMS & TLS 1.2+ (SC-28)
│   ├── rds-postgresql/       # Story 1.5: Multi-AZ RDS PostgreSQL with TLS 1.2+ & IAM auth (CP-9)
│   ├── kubernetes-eks/       # Story 2.1 & 2.2: Private EKS control plane, IMDSv2, Chrony Amazon Time Sync
│   ├── irsa-factory/         # Story 2.3 & 4.8: Granular IAM Roles for Service Accounts (IRSA)
│   ├── airgap-registry/      # Story 3.1: Day-0 Seed ECR repositories with KMS encryption
│   ├── networking-pki/       # Private Route53 DNS, internal PKI endpoints
│   ├── kubernetes-aks/       # Azure AKS government baseline (FIPS 140-2)
│   └── kubernetes-gke/       # GCP GKE government baseline (Shielded nodes, CMEK)
├── environments/
│   ├── poc-cloud-minimal/    # Low-cost single-node / burstable cloud testing environment
│   ├── dev/                  # Development enclave
│   ├── test/                 # Integration test enclave
│   ├── stg/                  # Staging enclave (production parity)
│   └── prod/                 # Full production enclave (Multi-AZ HA, strict audit logging)
├── manifests/
│   ├── aws-load-balancer-controller/ # Story 3.2: Air-gapped NLB controller manifests
│   ├── cato-oscal-exporter/          # Story 5.6: Automated OSCAL compliance exporter CronJob
│   ├── external-secrets/             # Story 2.4: External Secrets Operator and ClusterSecretStores
│   ├── flux-system/                  # Story 2.5: Flux v2 controllers and GitOps sync
│   ├── harbor/                       # Story 3.1 & 4.3: Hardened Harbor registry manifests
│   ├── istio-core/                   # Story 4.4: Istio CRDs, STRICT mTLS, Ingress Gateway
│   ├── keycloak/                     # Story 4.6: Keycloak SSO and PostgreSQL manifests
│   ├── kyverno/                      # Story 5.1: Kyverno admission controller & policy pack
│   ├── monitoring/                   # Story 5.3 & 5.5: LGTM stack and cATO executive dashboard
│   ├── neuvector/                    # Story 5.2: NeuVector Active Cyber Defense DaemonSet
│   ├── smoke-tests/                  # Story 6.2: Automated pre-flight & post-upgrade smoke test Jobs
│   ├── vault/                        # Story 4.5: HashiCorp Vault with AWS KMS auto-unseal
│   ├── vector/                       # Story 5.4: Vector OCSF telemetry shipper DaemonSet
│   └── velero/                       # Story 6.4: Velero backup & DR with S3/KMS and EBS snapshots
└── scripts/                          # Operational automation and lifecycle CLIs
```

---

## 🛠 Automation Scripts Inventory

| Script | Purpose & Story |
| :--- | :--- |
| [`seed-ecr-bootstrap.sh`](scripts/seed-ecr-bootstrap.sh) | **Story 3.1**: Pre-seeds Day-0 container images (Flux, CoreDNS, VPC CNI, Harbor) into private ECR repos before cluster launch. |
| [`deploy-aws-load-balancer-controller.sh`](scripts/deploy-aws-load-balancer-controller.sh) | **Story 3.2**: Provisions AWS Load Balancer Controller with IRSA for internal NLBs. |
| [`deploy-external-secrets.sh`](scripts/deploy-external-secrets.sh) | **Story 2.4**: Deploys ESO and wires `ClusterSecretStore` to AWS Secrets Manager via IRSA. |
| [`deploy-flux-bootstrap.sh`](scripts/deploy-flux-bootstrap.sh) | **Story 2.5**: Bootstraps air-gapped Flux v2 GitOps engine pulling from internal registries. |
| [`deploy-hardened-harbor.sh`](scripts/deploy-hardened-harbor.sh) | **Story 4.3**: Deploys Harbor with S3/KMS backend, Keycloak OIDC, and Kyverno Cosign admission rules. |
| [`deploy-istio-zero-trust.sh`](scripts/deploy-istio-zero-trust.sh) | **Story 4.4**: Deploys Istio service mesh in STRICT mTLS mode with egress lockdown. |
| [`deploy-vault-kms-raft.sh`](scripts/deploy-vault-kms-raft.sh) | **Story 4.5**: Provisions HashiCorp Vault cluster with Integrated Raft storage and AWS KMS auto-unsealing. |
| [`deploy-keycloak-sso.sh`](scripts/deploy-keycloak-sso.sh) | **Story 4.6**: Configures Keycloak DoD PKI/CAC authentication and OIDC realms. |
| [`deploy-kyverno-policy-pack.sh`](scripts/deploy-kyverno-policy-pack.sh) | **Story 5.1**: Deploys Kyverno admission controller and NIST SP 800-53 Rev 5 policy pack. |
| [`deploy-neuvector-acd.sh`](scripts/deploy-neuvector-acd.sh) | **Story 5.2**: Deploys NeuVector DaemonSet in Protect mode with real-time process quarantine. |
| [`deploy-oscal-exporter.sh`](scripts/deploy-oscal-exporter.sh) | **Story 5.6**: Deploys scheduled OSCAL exporter CronJob generating machine-readable SSPs for eMASS. |
| [`deploy-velero-dr.sh`](scripts/deploy-velero-dr.sh) | **Story 6.4**: Provisions Velero backup controller with AWS plugin, private S3 bucket, and daily snapshot schedules. |
| [`run-smoke-tests.sh`](scripts/run-smoke-tests.sh) | **Story 6.2**: Runs pre-flight and post-upgrade smoke tests validating mTLS, ingress, secrets, storage, and DR. |
| [`ironbank-cve-triage.py`](scripts/ironbank-cve-triage.py) | **Story 6.3**: Zero-dependency Python CLI scanning tenant workloads, tracking MTTR against DoD 14-day SLA, and applying tag patches. |
| [`dr-restore-drill.sh`](scripts/dr-restore-drill.sh) | **Story 6.5**: Executes automated cross-region DR restoration drills, rehydrating RDS and Velero snapshots, and producing CP-9/CP-10 audit logs. |

---

## 🚀 Environment Deployment Quickstart

### 1. Configure Target Environment
Select the desired environment (`poc-cloud-minimal`, `dev`, `test`, `stg`, or `prod`):
```bash
cd meshdefense-clusters/environments/poc-cloud-minimal
```

### 2. Initialize and Apply Terraform
```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### 3. Verify Enclave Infrastructure Outputs
Verify that all 6 KMS CMKs, private VPC endpoints, and IRSA role ARNs are exported:
```bash
terraform output all_kms_key_arns
terraform output irsa_role_arns
```
