# meshdefense-bigbang (Mirrored Big Bang Chart)

This repository hosts the mirrored, air-gapped **Platform One Big Bang** Helm umbrella chart, offline packaging scripts, and dependency vendoring mechanisms for disconnected DoD IL6 cloud enclaves.

## Overview

Platform One Big Bang is an umbrella chart orchestrating core DevSecOps capabilities:
- **Service Mesh**: Istio (mTLS STRICT, egress lockdown)
- **Zero-Trust & Policy**: Kyverno / OPA Gatekeeper
- **Runtime Defense**: NeuVector / Twistlock
- **Observability**: Prometheus Operator, Grafana, Alertmanager, Loki, Jaeger
- **Identity & SSO**: Keycloak
- **Log Forwarding**: Fluentbit

In disconnected IL6 environments, Helm charts and container images cannot be fetched on-the-fly from the internet. This repository maintains the vendored offline chart dependencies and provides scripts for packaging, signing, and syncing to high-side Git / OCI registries.

---

## Directory Structure

```
meshdefense-bigbang/
├── README.md
├── chart/
│   ├── Chart.yaml              # Big Bang umbrella chart definition
│   ├── values.yaml             # Baseline Big Bang default values configured for internal registry
│   ├── charts/                 # Vendored dependency charts (.tgz packages for airgap)
│   └── templates/
│       ├── _helpers.tpl
│       └── bigbang-packages.yaml # Helm template generating package HelmReleases
├── keys/
│   └── ironbank.pub            # DoD Platform One Iron Bank Cosign ECDSA public key
├── scripts/
│   ├── artifact-harvester.py   # DoD IL6 Harvester CLI & OCI Air-Gap Sync Pipeline (Story 4.1)
│   ├── mirror-bigbang.sh       # Mirror upstream Repo One git & charts to airgap bundle
│   ├── vendor-dependencies.sh  # Download all subchart .tgz files for 100% offline installs
│   └── verify-signatures.sh    # Cosign validation with DoD P1 public keys
└── versions/
    └── release-matrix.yaml     # Big Bang, Flux v2, and Kubernetes version compatibility matrix
```

---

## Story 4.1: Automated Air-Gap Harvester & OCI Sync Pipeline

The unified [`artifact-harvester.py`](file:///Users/patrykp/Projects/MeshDefense/meshdefense-bigbang/scripts/artifact-harvester.py) utility automates the end-to-end low-side export and high-side import process, strictly validating Cosign signatures and encrypting the bundle with AES-256-CBC PBKDF2.

### 1. Low-Side Harvest (Internet-Connected Pipeline)
```bash
python3 meshdefense-bigbang/scripts/artifact-harvester.py harvest \
  --matrix meshdefense-bigbang/versions/release-matrix.yaml \
  --bigbang-version 3.30.0 \
  --images-file meshdefense-apps/images/ironbank-images.txt \
  --chart-dir meshdefense-bigbang/chart \
  --output /transfer/meshdefense-airgap-bundle.tar.gz.enc \
  --encrypt-pass "DiodePassphrase2026!"
```

### 2. High-Side Air-Gap Ingest (Disconnected IL6 Bastion)
```bash
python3 meshdefense-bigbang/scripts/artifact-harvester.py ingest \
  --bundle /transfer/meshdefense-airgap-bundle.tar.gz.enc \
  --decrypt-pass "DiodePassphrase2026!" \
  --registry registry.il6.meshdefense.internal \
  --project ironbank
```

