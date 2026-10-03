# meshdefense-apps (Hardened Applications, Security Packages & Workloads)

This directory houses all tenant mission packages, continuous telemetry shippers, active cyber defense policies, and Iron Bank container image manifests that operate within the air-gapped **MeshDefense** enclave alongside Platform One's Big Bang.

All container images are sourced strictly from DoD Iron Bank (`registry1.dso.mil`) and verified with Cosign cryptographic signatures.

---

## 📦 Application & Security Package Inventory

```
meshdefense-apps/
├── images/
│   ├── ironbank-catalog.yaml   # Authoritative catalog of approved Iron Bank images, digests, and SBOM refs
│   ├── ironbank-images.txt     # Flat inventory list for low-side Skopeo image mirror jobs
│   └── app-images.txt          # Complete inventory of application images to mirror
├── packages/
│   ├── anchore-grype/          # Story 4.3: Air-gap container vulnerability scanning & DB synchronization
│   ├── argocd/                 # Multi-cluster application delivery with GitOps
│   ├── gitlab/                 # Story 4.7: DoD-hardened DevSecOps CI/CD engine with GitLab Runner
│   ├── harbor/                 # Story 4.3: OCI registry with S3/KMS backend, Keycloak OIDC, and Cosign gates
│   ├── keycloak/               # Story 4.6: Enterprise DoD SSO with CAC/PKI and FIDO2/WebAuthn
│   ├── kyverno/                # Story 5.1: NIST SP 800-53 Rev 5 admission controller policy pack
│   ├── monitoring/             # Story 5.3 & 5.5: LGTM stack (Loki S3, Prometheus M-21-31, cATO dashboard)
│   ├── neuvector/              # Story 5.2: Container runtime Active Cyber Defense (Protect mode)
│   ├── oscal-exporter/         # Story 5.6: Automated OSCAL JSON/YAML compliance exporter for eMASS
│   ├── sonarqube/              # Story 4.7: Static Application Security Testing (SAST) and code quality
│   ├── vault/                  # Story 4.5: HashiCorp Vault with Integrated Raft and KMS auto-unsealing
│   ├── vector/                 # Story 5.4: Vector OCSF v1.1.0 telemetry normalizer with NIST Control tags
│   └── velero/                 # Story 6.4: Velero backup & DR package with S3/KMS and EBS snapshotting
└── scripts/
    ├── airgap-image-sync.sh    # Low-side export and high-side import Skopeo synchronization script
    ├── airgap-chart-sync.sh    # Push Helm charts to internal OCI Harbor registry
    └── update-vuln-db.sh       # Offline vulnerability database updater for Trivy and Grype
```

---

## 🛡️ Security Capabilities by Package

| Package | Purpose | NIST SP 800-53 Controls | Security Features |
| :--- | :--- | :--- | :--- |
| **`anchore-grype`** | Vulnerability Scanner | **RA-5, SI-2** | Scans container images for CVEs using offline vulnerability databases. |
| **`gitlab`** | CI/CD Platform | **CM-3, AC-3, SC-8** | Dedicated runner pool, root volume KMS encryption, strict TLS database connections. |
| **`keycloak`** | Identity & SSO Provider | **IA-2, IA-5** | Client certificate PKI/CAC authentication, SAML/OIDC identity brokering. |
| **`kyverno`** | Policy Admission Gate | **AC-3, CM-7, SI-7** | Blocks non-root, privilege escalation, host namespaces, and unsigned Iron Bank images. Emits JSON audit logs. |
| **`monitoring`** | Observability & cATO | **AU-2, AU-6, CA-7** | Loki with S3 object storage; Prometheus with 90-day retention (DoD M-21-31); real-time cATO executive dashboard. |
| **`neuvector`** | Active Cyber Defense | **SI-4** | DaemonSet in `Protect` mode; behavioral zero-trust network rules; automated real-time process quarantine. |
| **`oscal-exporter`**| Compliance Exporter | **CA-7, AU-6** | Scheduled pipeline producing standardized OSCAL v1.1.0 SSP and Assessment Results for direct eMASS ingestion. |
| **`sonarqube`** | Static Code Analysis | **SA-11, SI-2** | Automated SAST and security hotspots detection integrated with GitLab CI/CD. |
| **`vault`** | Secrets & Cryptography | **SC-12, SC-13, IA-5** | Multi-AZ Raft clustering, automated AWS KMS auto-unsealing, envelope encryption for tokens. |
| **`vector`** | Telemetry Normalizer | **AU-2, AU-3, AU-12** | OCSF v1.1.0 JSON format normalization enriched with NIST Control IDs; forwards to S3-backed Loki. |
| **`velero`** | Backup & Recovery | **CP-9, CP-10, SC-28** | IRSA authentication, private encrypted S3 bucket, EBS native volume snapshots, daily cluster state backups. |

---

## 🔍 Iron Bank CVE Triage & MTTR Compliance

MeshDefense enforces an automated continuous vulnerability triage pipeline ([`ironbank-cve-triage.py`](../meshdefense-clusters/scripts/ironbank-cve-triage.py)) validating all tenant workloads against the authoritative Iron Bank catalog ([`ironbank-catalog.yaml`](images/ironbank-catalog.yaml)).

### Scanning for Compliance:
```bash
python3 meshdefense-clusters/scripts/ironbank-cve-triage.py
```

### Applying In-Place Upgrades:
```bash
python3 meshdefense-clusters/scripts/ironbank-cve-triage.py --apply-patch
```
Guarantees tenant workloads maintain an average vulnerability MTTR under 14 days to preserve their active Continuous Authority to Operate (cATO).
