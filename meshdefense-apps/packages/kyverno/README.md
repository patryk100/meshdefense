# Kyverno NIST 800-53 Policy Pack & Admission Event Streaming (Story 5.1)

## Overview
This package deploys Kyverno admission controllers configured with NIST SP 800-53 policy enforcement and real-time structured JSON admission event streaming for continuous Authority to Operate (cATO) telemetry.

## Enforced Security Controls

| Control ID | Control Name | Enforced Policy | Validation Failure Action |
|---|---|---|---|
| **AC-3 / CM-7** | Access Enforcement / Least Functionality | `nist-800-53-disallow-privileged-containers` | **Enforce** (Reject admission) |
| **AC-3** | Access Enforcement | `nist-800-53-disallow-privilege-escalation` | **Enforce** (Reject admission) |
| **AC-3 / CM-7** | Access Enforcement | `nist-800-53-require-run-as-non-root` | **Enforce** (Reject admission) |
| **AC-3 / SC-7** | Boundary Protection & Isolation | `nist-800-53-disallow-host-namespaces` | **Enforce** (Reject admission) |
| **SI-7 / SA-11**| Supply Chain & Code Integrity | `nist-800-53-enforce-cosign-signatures` | **Enforce** (Reject admission) |

## Structured JSON Audit Logging & cATO Streamer

Kyverno is configured with `--loggingFormat=json` and deployed alongside the `kyverno-event-streamer` daemon which normalizes admission reviews into structured JSON records conforming to NIST 800-53 AU-3:

```json
{
  "timestamp": "2026-10-02T22:00:00Z",
  "telemetry_source": "kyverno.admission.controller",
  "enclave": "poc-minimal",
  "event_type": "cATO_ADMISSION_AUDIT",
  "decision": "BLOCK",
  "nist_controls": ["AC-3", "CM-7"],
  "policy": {
    "name": "nist-800-53-disallow-privileged-containers",
    "kind": "ClusterPolicy",
    "rule": "check-privileged-containers"
  },
  "workload": {
    "namespace": "tenant-telemetry",
    "name": "rogue-privileged-pod",
    "kind": "Pod"
  },
  "admission_detail": {
    "action": "AdmissionReview",
    "reason": "PolicyViolation",
    "message": "Privileged containers are strictly forbidden under NIST 800-53 AC-3 / CM-7.",
    "reporting_component": "kyverno"
  }
}
```

These structured events are automatically aggregated by Vector/Fluent-Bit into Loki and CloudWatch for automated AO compliance dashboards and SIEM alerting.
