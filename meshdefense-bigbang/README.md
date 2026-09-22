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
├── scripts/
│   ├── mirror-bigbang.sh       # Mirror upstream Repo One git & charts to airgap bundle
│   ├── vendor-dependencies.sh  # Download all subchart .tgz files for 100% offline installs
│   └── verify-signatures.sh    # Cosign validation with DoD P1 public keys
└── versions/
    └── release-matrix.yaml     # Big Bang, Flux v2, and Kubernetes version compatibility matrix
```

---

## Mirroring Workflow (Low-Side to High-Side)

### 1. Low-Side Export (Internet-Connected Machine)
```bash
cd scripts
./mirror-bigbang.sh --tag 2.46.0 --export-dir /path/to/transfer-media
./vendor-dependencies.sh
```

### 2. High-Side Ingest (Air-Gapped IL6 Bastion)
```bash
# Verify Cosign signatures
./verify-signatures.sh --bundle /media/transfer/bigbang-2.46.0.tar.gz

# Push chart to internal Harbor OCI registry
helm push chart/ oci://registry.il6.meshdefense.internal/bigbang/
```
