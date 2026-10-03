# meshdefense-gitops (Flux v2 & Kustomize Environment Overlays)

The `meshdefense-gitops` repository houses the declarative **GitOps** pipeline orchestrating Platform One's **Big Bang** across all target environments (`dev`, `test`, `stg`, `prod`) using **Flux v2** and **Kustomize**.

---

## 🏛 GitOps Architecture & Pattern

This repository implements standard, air-gapped GitOps reconciliation:
1. **Clusters Entrypoint (`clusters/<env>`)**: The root Flux Kustomization applied during cluster bootstrapping, pointing to this repository.
2. **Base Configuration (`base/`)**: Common definitions for the Big Bang `HelmRelease`, internal `OCIRepository` / `GitRepository`, and baseline zero-trust policies (Istio STRICT mTLS, default-deny network rules).
3. **Environment Overlays (`environments/<env>`)**: Environment-specific patches (replica sizing, domains, enabled add-ons, and Mozilla SOPS encrypted secrets).
4. **Tenant Customization Engine (`tenants/`)**: Declarative tenant onboarding templates allowing application teams to self-serve workloads within strict guardrails.

---

## 📁 Directory Structure & Layout

```
meshdefense-gitops/
├── clusters/
│   ├── dev/                    # Flux bootstrap sync targeting environments/dev
│   │   ├── flux-system/
│   │   └── bigbang.yaml
│   ├── test/                   # Flux bootstrap sync targeting environments/test
│   ├── stg/                    # Flux bootstrap sync targeting environments/stg
│   └── prod/                   # Flux bootstrap sync targeting environments/prod
├── base/
│   ├── kustomization.yaml      # Aggregates base GitOps definitions
│   ├── bigbang-helmrelease.yaml# Flux v2 HelmRelease for Platform One Big Bang
│   ├── bigbang-repo.yaml       # OCIRepository pointing to internal chart mirror
│   └── core-values.yaml        # Immutable base values (Istio mTLS, Kyverno, NeuVector)
├── environments/
│   ├── dev/                    # Development (single-replica, dev domain)
│   ├── test/                   # Test (integration testing, 2 replicas)
│   ├── stg/                    # Staging (production parity, 3 replicas)
│   └── prod/                   # Production (Multi-AZ HA, strict audit logging)
├── tenants/
│   ├── base/                   # Reusable tenant template (Quota, Limits, NetPol, Cert, Gateway)
│   ├── platform-core/          # Platform core services (Keycloak, Vault, GitLab)
│   └── mission-analytics/      # Mission analytics workload overlay
└── scripts/
    ├── tenant-customization-engine.py # Parameterized tenant overlay generator
    └── tenant-onboarding-factory.py   # Declarative developer self-service onboarding tool
```

---

## 📊 Environment Comparison Matrix

| Environment | Ingress Domain | Sizing & Replicas | Addons Enabled | Strict mTLS |
| :--- | :--- | :--- | :--- | :--- |
| **`dev`** | `*.dev.il6.meshdefense.internal` | Minimal / 1 replica | SonarQube, Monitoring | Strict |
| **`test`** | `*.test.il6.meshdefense.internal` | Standard / 2 replicas | GitLab, SonarQube, Monitoring | Strict |
| **`stg`** | `*.stg.meshdefense.internal` | Production Parity / 3 replicas | Full suite (GitLab, Sonar, Vault, Keycloak) | Strict |
| **`prod`** | `*.prod.il6.meshdefense.internal` | High Availability / 3+ replicas | Full suite + SIEM Audit Exporter | Strict |

---

## 🔐 Secrets Management with SOPS

All sensitive parameters (database credentials, registry tokens, private keys) are encrypted at rest in Git using **Mozilla SOPS** backed by cloud KMS:

```bash
# Encrypting a secret for the prod overlay
sops --encrypt \
  --kms "arn:aws-us-gov:kms:us-gov-west-1:123456789012:alias/meshdefense-prod-secrets" \
  registry-secret.yaml > registry-secret.enc.yaml
```

Flux v2 decrypts these secrets at reconciliation time inside the cluster using the cluster's IRSA role permissions.

---

## 🚀 How to Use: Tenant Onboarding & Workload Deployment

### 1. Define a Tenant Specification
Application teams submit a declarative `TenantOnboardingRequest` YAML:

```yaml
apiVersion: onboarding.meshdefense.io/v1alpha1
kind: TenantOnboardingRequest
metadata:
  name: telemetry-analytics
spec:
  tenant:
    name: telemetry-analytics
    namespace: tenant-telemetry
    serviceAccount: telemetry-analytics-sa
    environment: poc-minimal
  resources:
    requests: { cpu: "4", memory: "8Gi" }
    limits: { cpu: "8", memory: "16Gi" }
    pods: "40"
  ingress:
    enabled: true
    hosts:
      - "telemetry.apps.poc-minimal.il6.meshdefense.internal"
    tlsSecretName: "telemetry-analytics-ingress-cert"
  egressRules:
    - name: egress-internal-rds-postgres
      hosts: ["postgres.rds.poc-minimal.il6.meshdefense.internal"]
      ports: [{ number: 5432, protocol: TCP, name: postgres-tcp }]
      location: MESH_EXTERNAL
  irsa:
    enabled: true
    roleName: "meshdefense-poc-minimal-irsa-telemetry-analytics"
    inlinePolicyStatements:
      - sid: "AllowS3MetricsStorage"
        effect: "Allow"
        actions: ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
        resources: ["arn:aws:s3:::meshdefense-poc-minimal-*-loki/*"]
```

### 2. Generate Enclave Manifests
Run the Onboarding Factory to generate the hardened manifests:
```bash
python3 meshdefense-gitops/scripts/tenant-onboarding-factory.py \
  --spec meshdefense-gitops/tenants/telemetry-analytics/tenant-onboarding.yaml \
  --output-dir meshdefense-gitops/tenants/telemetry-analytics/manifests
```

The tool automatically produces:
- Hardened Namespace & ServiceAccount with IRSA annotations
- STRICT mTLS `PeerAuthentication` (NIST 800-53 SC-8)
- Default-deny `NetworkPolicy` with explicit allow-lists
- Istio `ServiceEntry` for declared egress endpoints
- Cert-Manager TLS certificate and Istio `VirtualService`
- Terraform snippet for AWS IRSA IAM role creation
- Flux-ready `kustomization.yaml`
