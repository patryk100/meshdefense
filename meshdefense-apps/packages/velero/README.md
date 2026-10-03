# MeshDefense Velero Backup & Disaster Recovery Automation (Story 6.4)

## Overview
This package delivers automated cluster state and persistent volume disaster recovery capabilities for MeshDefense enclaves under **NIST SP 800-53 CP-9 (Information System Backup)** and **CP-10 (Information System Recovery and Reconstitution)**.

## Security & Architecture Highlights
- **AWS IRSA Integration**: Operates under least-privilege IAM role `meshdefense-poc-minimal-irsa-velero` using `AssumeRoleWithWebIdentity`. Zero static IAM access keys exist in the cluster.
- **S3 & SSE-KMS Encryption**: Target backup storage location utilizes the private air-gapped S3 bucket (`meshdefense-poc-minimal-velero-backups-ju9q2f`) enforcing TLS 1.2+ and dedicated cryptographic key `kms_s3_key_arn`.
- **Native EBS Volume Snapshots**: Utilizes the official AWS Velero plugin (`velero-plugin-for-aws:v1.9.2`) to orchestrate crash-consistent AWS EBS snapshots alongside Kubernetes metadata.
- **Automated Schedules**:
  - `daily-cluster-backup`: Runs every day at 02:00 UTC with 30-day retention (`ttl: 720h`), capturing all tenant namespaces and persistent volumes.
  - `weekly-crds-platform-state-backup`: Runs weekly on Sunday at 04:00 UTC with 90-day retention (`ttl: 2160h`), archiving cluster-wide CRDs, RBAC bindings, StorageClasses, and Admission Webhooks.
- **Defense-in-Depth**: Hardened non-root runtime container (`runAsUser: 65534`), read-only root filesystems, and strict `NetworkPolicy` limiting egress strictly to DNS and Kubernetes API server.

## Verification & Deployment
```bash
# Deploy Velero resources via manifests
kubectl apply -k meshdefense-clusters/manifests/velero/

# Check backup storage location status
kubectl get backupstoragelocation -n velero

# Check scheduled jobs
kubectl get schedules -n velero
```
