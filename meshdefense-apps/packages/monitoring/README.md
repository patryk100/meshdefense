# MeshDefense Monitoring Stack (LGTM) - GovCloud Tuning

## Overview
This package deploys the hardened LGTM (Loki, Grafana, Tempo, Prometheus) observability stack configured specifically for DoD IL6 / AWS GovCloud air-gapped environments under Story 5.3.

## Architectural Highlights
- **Loki S3 Object Storage Persistence**: Log chunks and TSDB indices are persisted to the air-gapped S3 bucket (`meshdefense-poc-minimal-loki-logs-ju9q2f`) utilizing IAM Roles for Service Accounts (IRSA) and VPC S3 Gateway endpoints, eliminating local EBS node volume exhaustion.
- **OMB M-21-31 Compliance**: Retention policies for Prometheus, Loki, and Tempo are strictly configured to maintain active telemetry data for 90 days (`2160h`), adhering to federal EL1-EL3 logging directives.
- **Tempo Distributed Tracing**: Backed by S3 storage via IRSA, receiving OTLP gRPC/HTTP and Jaeger traces cluster-wide.
- **Pre-Loaded Grafana Dashboards**: Automatically provisioned with DoD STIG compliance, Istio strict mTLS coverage rate, zero-trust egress violations, Kyverno admission decisions, and NeuVector active threat quarantines.
- **cATO Executive Dashboard (Story 5.5)**: Pre-configured single-pane-of-glass ConMon dashboard for AO and CISO detailing:
  - Real-time ConMon policy failure rates & compliance health scoring.
  - Unpatched CVE Mean-Time-To-Remediate (MTTR).
  - Active Cyber Defense (ACD) real-time actions (quarantined processes, blocked lateral movement, egress exfiltration blocks).
  - Cryptographic supply chain provenance (Cosign signature validation vs blocked unsigned images).
  - OCSF event streams by NIST 800-53 control classification.
- **Zero-Trust Network Policies**: The `monitoring` namespace is protected with default-deny policies, whitelisting intra-namespace communication, telemetry ingestion from cluster workloads, and Ingress gateway access.

## Verification
Deploy manifests via Kustomize:
```bash
kubectl apply -k meshdefense-clusters/manifests/monitoring/
```
Verify that all components are running:
```bash
kubectl get pods,svc,pvc,netpol -n monitoring
```
