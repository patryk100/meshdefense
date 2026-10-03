# MeshDefense Vector Telemetry Normalization & Enrichment DaemonSet

## Overview
This package deploys the Vector DaemonSet across all nodes in the MeshDefense enclave. It complies with Story 5.4 by collecting disparate platform logs, filtering out ephemeral cluster noise, enriching payloads with **NIST SP 800-53 Rev 5** controls, and formatting all records into the **Open Cybersecurity Schema Framework (OCSF v1.1.0)** standard.

## Telemetry Sources
1. **Container Logs**: Streamed directly from `/var/log/pods` across every node.
2. **Kyverno Admission Events**: Evaluates admission webhook decisions against NIST controls CM-7 and AC-3.
3. **NeuVector Runtime Alerts & Syslog**: Ingests real-time lateral movement and active container threat alerts (`SI-4`) over HTTP webhook (`:8088`) and Syslog (`:514`).

## OCSF Schema & NIST 800-53 Mapping
All output events are transformed using Vector Remap Language (VRL) and tagged with:
- `category_name`: "Security Finding" / "Cloud / Infrastructure"
- `class_name`: "Detection Finding" (2001) / "Container Activity" (1007) / "Authentication & Authorization" (3002)
- `compliance.framework`: `NIST-SP-800-53-Rev5`
- `compliance.control_id`:
  - `SC-7`: Istio Zero-Trust mTLS and egress boundary controls.
  - `SC-12`: HashiCorp Vault KMS auto-unseal and cryptographic keys.
  - `IA-2`: Keycloak CAC/PKI and FIDO2/WebAuthn identity federation.
  - `AC-3` / `CM-7`: Kyverno non-root, privilege escalation, and Iron Bank admission gates.
  - `SI-4`: NeuVector Active Cyber Defense runtime interception and quarantine.
  - `AU-2`: General cluster event and audit trail generation.

## Destination Sinks
- **Loki OCSF Ingest**: `http://loki.monitoring.svc.cluster.local:3100` for querying in Grafana and long-term M-21-31 S3 persistence.
