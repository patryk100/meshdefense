# meshdefense-bigbang (Mirrored Big Bang Chart & Packaging Engine)

The `meshdefense-bigbang` repository hosts the mirrored, air-gapped **Platform One Big Bang** Helm umbrella chart, offline packaging automation, and dependency vendoring mechanisms for disconnected DoD IL6 cloud enclaves.

---

## 🏛 Big Bang Architecture & Core Services

Platform One Big Bang orchestrates foundational DevSecOps capabilities:
- **Zero-Trust Service Mesh**: Istio (`STRICT` mutual TLS, egress lockdown to `REGISTRY_ONLY`)
- **Policy Enforcement**: Kyverno / OPA Gatekeeper (NIST SP 800-53 controls)
- **Active Cyber Defense**: NeuVector container runtime protection (eBPF process & network quarantine)
- **Observability Stack**: Prometheus Operator, Grafana, Alertmanager, Loki, and Tempo
- **Identity & SSO**: Keycloak (DoD CAC/PKI and FIDO2 integration)
- **Log Shipper**: Vector / Fluent-Bit (OCSF format normalization)

In disconnected enclaves, Helm charts and container images cannot be retrieved from public networks. This repository maintains vendored offline packages and automated transfer pipelines for high-side ingestion.

---

## 📁 Repository Structure & Contents

```
meshdefense-bigbang/
├── chart/
│   ├── Chart.yaml              # Big Bang umbrella chart definition
│   ├── values.yaml             # Baseline default values configured for internal OCI registry
│   ├── charts/                 # Vendored dependency subcharts (.tgz archives for offline install)
│   └── templates/
│       ├── _helpers.tpl
│       └── bigbang-packages.yaml # Template generating Flux HelmReleases for enabled packages
├── keys/
│   └── ironbank.pub            # Platform One Iron Bank Cosign ECDSA public verification key
├── scripts/
│   ├── artifact-harvester.py   # DoD IL6 Harvester CLI & OCI Air-Gap Sync Pipeline
│   ├── upstream-diff-validator.py # Big Bang release comparison & breaking change analyzer
│   ├── mirror-bigbang.sh       # Mirror upstream Repo One git & charts to airgap bundle
│   ├── vendor-dependencies.sh  # Download all subchart .tgz files for 100% offline installs
│   └── verify-signatures.sh    # Cosign cryptographic validation with DoD public keys
└── versions/
    └── release-matrix.yaml     # Big Bang, Flux v2, and Kubernetes version compatibility matrix
```

---

## 🚀 How to Use & Operate

### 1. Air-Gapped Artifact Harvesting & Ingestion
The [`artifact-harvester.py`](scripts/artifact-harvester.py) utility manages end-to-end artifact promotion across security boundaries with Cosign validation and encrypted packaging.

#### Step A: Low-Side Harvest (Internet-Connected)
```bash
python3 meshdefense-bigbang/scripts/artifact-harvester.py harvest \
  --matrix meshdefense-bigbang/versions/release-matrix.yaml \
  --bigbang-version 3.30.0 \
  --images-file meshdefense-apps/images/ironbank-images.txt \
  --chart-dir meshdefense-bigbang/chart \
  --output /transfer/meshdefense-airgap-bundle.tar.gz.enc \
  --encrypt-pass "DiodePassphrase2026!"
```

#### Step B: High-Side Ingest (Air-Gapped Enclave Bastion)
```bash
python3 meshdefense-bigbang/scripts/artifact-harvester.py ingest \
  --bundle /transfer/meshdefense-airgap-bundle.tar.gz.enc \
  --decrypt-pass "DiodePassphrase2026!" \
  --registry ${REGISTRY_DOMAIN} \
  --project ironbank
```

---

### 2. Upstream Release Diff & Breaking Change Validation
Before initiating platform upgrades, run [`upstream-diff-validator.py`](scripts/upstream-diff-validator.py) to compare versions, analyze release notes for breaking structural changes, and verify Kubernetes/Flux compatibility:

#### Interactive Terminal Report:
```bash
python3 meshdefense-bigbang/scripts/upstream-diff-validator.py --target 3.31.0
```

#### CI/CD Upgrade Gate (Automated Pipeline):
```bash
python3 meshdefense-bigbang/scripts/upstream-diff-validator.py \
  --target 3.31.0 \
  --fail-on-critical \
  --output json > upgrade-risk-report.json
```
This utility prevents broken syncs by detecting deprecated chart values and breaking schema alterations before git commits are merged.
