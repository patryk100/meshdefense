# meshdefense-apps (Mirrored Applications & Container Workloads)

This repository / sub-component contains all mirrored application packages, Iron Bank container image manifests, and synchronization scripts that run in the air-gapped **MeshDefense** environment alongside Platform One's Big Bang.

## Overview

Big Bang provides the foundational DevSecOps core (Istio, Gatekeeper, NeuVector, Monitoring). `meshdefense-apps` hosts the application workloads and mission packages that operate within this service mesh.

All container images are sourced strictly from DoD Iron Bank (`registry1.dso.mil`) and mirrored into the enclave's internal Harbor registry.

---

## Directory Structure

```
meshdefense-apps/
├── README.md
├── packages/
│   ├── gitlab/                 # DevSecOps CI/CD, Git repo hosting, Runner configs
│   ├── sonarqube/              # Code quality, static code analysis (SAST)
│   ├── neuvector/              # Container runtime defense & zero-trust network rules
│   ├── keycloak/               # DoD PKI / CAC SSO, OIDC & SAML identity provider
│   ├── vault/                  # Secrets engine, KMS integration, PKI CA
│   ├── monitoring/             # Grafana dashboards, Alertmanager DoD alerts
│   └── anchore-grype/          # Air-gap container vulnerability scanning & DB sync
├── images/
│   ├── ironbank-images.txt     # List of upstream Iron Bank container images
│   └── app-images.txt          # Complete inventory of application images to mirror
└── scripts/
    ├── airgap-image-sync.sh    # Skopeo sync script (Low-side export -> High-side import)
    ├── airgap-chart-sync.sh    # Push Helm charts to internal OCI Harbor registry
    └── update-vuln-db.sh       # Offline vulnerability database updater for Trivy/Grype
```

---

## Image & Package Mirroring Procedure

### Step 1: Low-Side Sync & Archive
Run from an internet-connected staging bastion:
```bash
cd scripts
./airgap-image-sync.sh --mode export --file ../images/app-images.txt --archive /media/transfer/meshdefense-images.tar
```

### Step 2: Diode / Boundary Transfer
Transfer the tar archive across the air-gap data diode to the high-side IL6 environment.

### Step 3: High-Side Ingest to Internal Harbor
Run from the high-side air-gap bastion:
```bash
./airgap-image-sync.sh --mode import --archive /media/transfer/meshdefense-images.tar --registry registry.il6.meshdefense.internal
```

---

## Story 4.3: Hardened Harbor Registry (S3 Backend, Keycloak OIDC & Cosign)

Harbor is configured as the immutable, high-side source of truth:
- **Storage Backend**: AWS S3 with SSE-KMS storage encryption and `disableredirect: true` to force VPC interface endpoints.
- **Identity Provider**: Keycloak OIDC federation (`realm: baby-yoda`, group mapping to `platform-administrators`).
- **Scanning Engine**: In-cluster Trivy vulnerability scanner operating in offline mode.
- **Signature Admission Gate**: Kyverno `ClusterPolicy` requiring Cosign signatures on all admitted images from Iron Bank.

To deploy or update:
```bash
meshdefense-clusters/scripts/deploy-hardened-harbor.sh
```

