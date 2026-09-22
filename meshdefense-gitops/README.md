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
