# MeshDefense Automated OSCAL Exporter

## Overview
This utility automates compliance artifact generation under Story 5.6 by periodically evaluating the enclave's live security controls against **NIST SP 800-53 Rev 5** and **DoD Cloud SRG IL6** baselines, producing standardized **Open Security Controls Assessment Language (OSCAL v1.1.0)** System Security Plan (SSP) and Assessment Results documents.

## Evaluated Security Controls
1. **AC-3 & CM-7**: Kyverno admission policies blocking non-root, privilege escalation, and unauthorized host configurations.
2. **SI-4**: NeuVector Active Cyber Defense DaemonSet status, behavioral network monitoring, and real-time process quarantine.
3. **SI-7**: Cosign cryptographic signature verification and Iron Bank provenance checks.
4. **SC-7**: Istio Zero-Trust strict mutual TLS (`STRICT`) and egress BlackHole perimeter protection.
5. **SC-12**: HashiCorp Vault AWS KMS auto-unseal and secret envelope encryption.
6. **IA-2**: Keycloak multi-factor authentication (CAC/PKI and FIDO2/WebAuthn).
7. **AU-2**: Vector telemetry collection, noise filtering, and OCSF normalization.

## Ingestion & Interoperability
- **Direct eMASS Ingestion**: Generates standardized OSCAL JSON format ingestible by eMASS, Xacta, and NIST OSCAL tools without manual spreadsheet translation.
- **In-Cluster Retrieval**: Constantly published into Kubernetes ConfigMap `oscal-latest-assessment-results` in namespace `cato` for programmatic retrieval via CI/CD and compliance dashboards.
- **S3 Compliance Archive**: Uses IRSA role `meshdefense-poc-minimal-eks-irsa-logging` to write immutable compliance snapshots into S3.

## Deployment & Execution
```bash
# Apply CronJob and bootstrap evaluation
kubectl apply -k meshdefense-clusters/manifests/cato-oscal-exporter/

# Retrieve latest OSCAL Assessment Results JSON
kubectl get configmap oscal-latest-assessment-results -n cato -o jsonpath='{.data.oscal-assessment-results\.json}' | jq .
```
