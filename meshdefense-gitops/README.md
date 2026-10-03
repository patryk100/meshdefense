# meshdefense-gitops (Flux v2 & Kustomize Environment Overlays)

This repository houses the declarative **GitOps** pipeline orchestrating Platform One's **Big Bang** across all target environments (`dev`, `test`, `stg`, `prod`) using **Flux v2** and **Kustomize**.

## Architecture

This repository implements the standard GitOps pattern for Big Bang in DoD air-gapped enclaves:
1. **Clusters Entrypoint (`clusters/<env>`)**: The root Flux Kustomization that is applied during cluster bootstrapping. It tracks this GitOps repository.
2. **Base Configuration (`base/`)**: Common definitions for the Big Bang `HelmRelease`, internal `GitRepository` / `OCIRepository`, and baseline security configurations (Istio mTLS STRICT, zero-trust network policies).
3. **Environment Overlays (`environments/<env>`)**: Custom overlays per environment that patch the Big Bang HelmRelease with environment-specific values (domains, replica counts, resources, enabled add-ons, and encrypted secrets via SOPS).

---

## Directory Layout

```
meshdefense-gitops/
├── README.md
├── clusters/
│   ├── dev/
│   │   ├── flux-system/        # GitOps toolkit sync components
│   │   └── bigbang.yaml        # Flux Kustomization targeting environments/dev
│   ├── test/
│   │   ├── flux-system/
│   │   └── bigbang.yaml
│   ├── stg/
│   │   ├── flux-system/
│   │   └── bigbang.yaml
│   └── prod/
│       ├── flux-system/
│       └── bigbang.yaml
├── base/
│   ├── kustomization.yaml      # Aggregates base GitOps definitions
│   ├── bigbang-helmrelease.yaml# Flux v2 HelmRelease for Platform One Big Bang
│   ├── bigbang-repo.yaml       # GitRepository / OCIRepository pointing to mirrored chart
│   └── core-values.yaml        # Base values (Istio, Iron Bank registry, Gatekeeper)
└── environments/
    ├── dev/                    # Development (single-replica, lightweight sizing, dev domain)
    │   ├── kustomization.yaml
    │   ├── values-patch.yaml
    │   └── secrets/
    │       ├── .sops.yaml
    │       └── registry-secret.enc.yaml
    ├── test/                   # Test / CI integration testing
    │   ├── kustomization.yaml
    │   ├── values-patch.yaml
    │   └── secrets/
    ├── stg/                    # Staging (production parity, HA, strict policies)
    │   ├── kustomization.yaml
    │   ├── values-patch.yaml
    │   └── secrets/
    └── prod/                   # Production (Multi-AZ HA, strict mTLS, audit logging)
        ├── kustomization.yaml
        ├── values-patch.yaml
        └── secrets/
```

---

## Environment Comparison Matrix

| Environment | Ingress Domain | Sizing & Replicas | Addons Enabled | Strict mTLS |
|---|---|---|---|---|
| **dev** | `*.dev.il6.meshdefense.internal` | Minimal / 1 replica | SonarQube, Monitoring | Permissive / Strict |
| **test** | `*.test.il6.meshdefense.internal` | Standard / 2 replicas | GitLab, SonarQube, Monitoring | Strict |
| **stg** | `*.stg.meshdefense.internal` | Production Parity / 3 replicas | Full suite (GitLab, Sonar, Vault, Keycloak) | Strict |
| **prod** | `*.prod.il6.meshdefense.internal` | High Availability / 3+ replicas | Full suite + SIEM Audit Exporter | Strict |

---

## Secrets Management with SOPS

All sensitive values (Harbor robot credentials, database passwords, TLS private keys) are encrypted in Git using **Mozilla SOPS** with cloud KMS (AWS KMS, Azure Key Vault, or GCP Cloud KMS):

```bash
# Encrypting a secret in the prod overlay
sops --encrypt --kms "arn:aws-us-gov:kms:us-gov-west-1:123456789012:key/..." \
  registry-secret.yaml > registry-secret.enc.yaml
```

Flux v2 decrypts these secrets at reconciliation time using the cluster's IAM role / KMS key permissions.

---

## Story 4.2: Hierarchical Kustomize Overlays & Tenant Customization Engine

MeshDefense enforces a 3-tier hierarchical Kustomize overlay structure:
`Base` $\rightarrow$ `Environment` $\rightarrow$ `Tenant`

```
meshdefense-gitops/
├── base/                   # Immutable security baselines (mTLS STRICT, Kyverno, NeuVector, Monitoring)
├── environments/           # Environment-level HA, replica sizing, and SOPS encrypted secrets
└── tenants/                # Tenant overlays parameterizing DNS, ingress certificates, and resource quotas
    ├── base/               # Reusable tenant template (Quota, Limits, NetworkPolicy, PeerAuth, Cert, Gateway)
    ├── platform-core/      # Tenant overlay for Keycloak, Vault, GitLab, SonarQube
    └── mission-analytics/  # Tenant overlay for Mission Data Science & Analytics workloads
```

### Parameterizing Tenants via Single YAML
To deploy a new tenant while preserving immutable security baselines, declare a single `tenant-values.yaml`:

```yaml
tenant:
  name: "mission-analytics"
  domain: "analytics.apps.meshdefense.internal"
  resources:
    requests: { cpu: "32", memory: "64Gi" }
    limits: { cpu: "64", memory: "128Gi" }
    pods: "150"
  ingress:
    hosts:
      - "analytics.apps.meshdefense.internal"
      - "*.analytics.apps.meshdefense.internal"
    tls_secret_name: "mission-analytics-ingress-cert"
```

Generate and validate the tenant overlay:
```bash
python3 meshdefense-gitops/scripts/tenant-customization-engine.py \
  --values meshdefense-gitops/tenants/mission-analytics/tenant-values.yaml \
  --output-dir meshdefense-gitops/tenants/mission-analytics

kubectl kustomize meshdefense-gitops/tenants/mission-analytics
```

---

## Story 4.8: Automated Tenant Onboarding GitOps Factory

The **Automated Tenant Onboarding GitOps Factory** (`meshdefense-gitops/scripts/tenant-onboarding-factory.py`) empowers application developers to self-serve workload deployments while strictly preserving DoD IL6 and NIST 800-53 zero-trust security guardrails.

### Developer Declarative Specification (`TenantOnboardingRequest`)
Developers submit a single declarative YAML file defining application metadata, service accounts, compute quotas, egress destinations, Kyverno exceptions, and AWS IRSA access:

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
    services: "10"
  ingress:
    enabled: true
    hosts:
      - "telemetry.apps.poc-minimal.il6.meshdefense.internal"
      - "*.telemetry.apps.poc-minimal.il6.meshdefense.internal"
    tlsSecretName: "telemetry-analytics-ingress-cert"
  egressRules:
    - name: egress-internal-rds-postgres
      hosts: ["postgres.rds.poc-minimal.il6.meshdefense.internal"]
      ports: [{ number: 5432, protocol: TCP, name: postgres-tcp }]
      resolution: DNS
      location: MESH_EXTERNAL
    - name: egress-external-s3-endpoints
      hosts: ["s3.us-east-1.amazonaws.com"]
      ports: [{ number: 443, protocol: HTTPS, name: https-s3 }]
      resolution: DNS
      location: MESH_EXTERNAL
  irsa:
    enabled: true
    roleName: "meshdefense-poc-minimal-irsa-telemetry-analytics"
    inlinePolicyStatements:
      - sid: "AllowS3MetricsStorage"
        effect: "Allow"
        actions: ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
        resources: ["arn:aws:s3:::meshdefense-poc-minimal-*-loki/*"]
  kyvernoExceptions:
    - policyName: "enforce-harbor-cosign-verification"
      ruleNames: ["verify-ironbank-and-harbor-signatures"]
      reason: "Telemetry collector requires vendor diagnostic agent certified by DISA STIG"
```

### Generated Artifacts
Running the factory automatically generates the complete hardened platform stack:
1. **Hardened Namespace & ServiceAccount**: Labeled with `istio-injection: enabled`, `pod-security.kubernetes.io/enforce: restricted`, and `eks.amazonaws.com/role-arn` IRSA annotation.
2. **STRICT mTLS PeerAuthentication**: Enforces encrypted pod-to-pod mutual TLS, rejecting unencrypted communication (NIST 800-53 SC-8).
3. **Egress ServiceEntry**: Declarative Istio ServiceEntries for external database and AWS API endpoints (NIST 800-53 SC-7).
4. **Microsegmentation NetworkPolicy**: Default-deny with explicit intra-namespace, ingress gateway, Prometheus scraper, and authorized egress port rules.
5. **Kyverno PolicyExceptions (v2beta1)**: Granular, scoped admission exceptions for specific workloads without degrading cluster-wide supply chain controls.
6. **Cert-Manager TLS Certificate & Istio Gateway**: ECDSA-256 automated 90-day certificates.
7. **AWS IRSA Terraform Configuration**: Dynamic least-privilege IAM role mapping with STS OIDC web identity trust.
8. **Kustomization Overlay**: Standard `kustomization.yaml` packaging all resources for Flux v2 GitOps reconciliation.

### Execution
```bash
python3 meshdefense-gitops/scripts/tenant-onboarding-factory.py \
  --spec meshdefense-gitops/tenants/telemetry-analytics/tenant-onboarding.yaml \
  --output-dir meshdefense-gitops/tenants/telemetry-analytics/manifests

kubectl kustomize meshdefense-gitops/tenants/telemetry-analytics/manifests
```
