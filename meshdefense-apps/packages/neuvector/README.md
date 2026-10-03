# NeuVector Active Cyber Defense (ACD) DaemonSet Integration (Story 5.2)

## Overview
NeuVector provides kernel-level active container security, network microsegmentation, and real-time process quarantine across all cluster nodes.

## Active Cyber Defense (ACD) Architecture

1. **Protect Mode Enforcement**:
   - Workloads run under active enforcement (`Protect` mode).
   - Any process execution or network traffic outside discovered baseline is actively blocked by the kernel-level Enforcer DaemonSet.

2. **Automated Network Rule Discovery**:
   - NeuVector intercepts Layer 7 container traffic using eBPF (`NV_SYSTEM_DRV_MODE=ebpf`).
   - Automatically builds declarative Layer-7 application security rules (`NvClusterSecurityRule` / `NvSecurityRule`).

3. **Real-Time Process Quarantine & SIEM Streaming (NIST 800-53 SI-4)**:
   - Automated incident response rules (`NvResponseRuleSecurityRule`) trigger immediate network and execution quarantine upon detecting container breakouts, reverse shells, or privilege escalation.
   - Quarantine events and unauthorized connection attempts are streamed to syslog (port 514) and webhook (`vector.monitoring:8088`) for cATO telemetry ingestion.

## CRD Policy Specifications

- **`NvClusterSecurityRule`** (`acd-protect-mode-baseline`): Declares cluster-wide Protect mode and baseline egress (DNS 53, HTTPS 443).
- **`NvResponseRuleSecurityRule`** (`acd-auto-quarantine-breakout`): Automatic quarantine on `Critical` incidents and webhook alerts on `Warning` violations.
- **`NvComplianceProfile`** (`default`): Maps runtime findings to NIST 800-53 SI-4 and DoD IL6 controls.

## Deployment

Deploy NeuVector CRDs, Controller, Manager, and Enforcer DaemonSet:
```bash
./meshdefense-clusters/scripts/deploy-neuvector-acd.sh
```
