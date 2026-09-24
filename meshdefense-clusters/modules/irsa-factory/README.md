# MeshDefense IRSA Factory Module

Dynamic, least-privilege IAM Roles for Service Accounts (IRSA) factory for Kubernetes workloads on AWS GovCloud / Commercial air-gapped enclaves.

## Architecture Overview

```
                      +----------------------------------+
                      | Kubernetes Pod (ServiceAccount)  |
                      |  - OIDC projected service token  |
                      +-----------------+----------------+
                                        |
                                        | 1. STS AssumeRoleWithWebIdentity
                                        v
                      +----------------------------------+
                      |         AWS STS Service          |
                      |  - Validates JWT against EKS     |
                      |    IAM OpenID Connect Provider   |
                      +-----------------+----------------+
                                        |
                                        | 2. Issues ephemeral scoped credentials
                                        v
                      +----------------------------------+
                      | Target AWS Resource (KMS/S3/etc) |
                      |  - Scoped to Namespace & SA      |
                      +----------------------------------+
```

## Security & Compliance
- **NIST 800-53 AC-3 (Access Enforcement) & AC-6 (Least Privilege)**: Zero static IAM user access keys. Every pod assumes a short-lived IAM role through AWS STS `AssumeRoleWithWebIdentity`.
- **NIST 800-53 SC-12 / SC-13 (Cryptographic Key Management)**: Cryptographic actions (`kms:Decrypt`, `kms:GenerateDataKey*`, `kms:CreateGrant`) are restricted to dedicated customer-managed keys (CMKs).
- **Strict OIDC Subject Matching**: Roles enforce `StringEquals` matching both the exact Kubernetes subject (`system:serviceaccount:<namespace>:<serviceaccount>`) and audience (`sts.amazonaws.com`).

## Built-In Workload Profiles
1. **External Secrets Operator (`external-secrets:external-secrets`)**: Read-only access to AWS Secrets Manager (`GetSecretValue`, `DescribeSecret`, `ListSecretVersionIds`) with CMK decryption.
2. **Velero (`velero:velero`)**: S3 backup bucket read/write, EC2 EBS volume snapshot lifecycle, and S3 KMS cryptographic operations.
3. **Logging Shipper (`logging:vector`)**: CloudWatch log group/stream ingestion with KMS log encryption, and optional S3 cold archive.
4. **HashiCorp Vault (`vault:vault`)**: KMS auto-unseal envelope encryption (`kms:Encrypt`, `kms:Decrypt`, `kms:DescribeKey`).
5. **AWS EBS CSI Driver (`kube-system:ebs-csi-controller-sa`)**: EBS volume lifecycle operations and KMS grant creation on the EBS CMK.

## Dynamic Custom Workloads
The module also accepts a `custom_roles` map for arbitrary application workloads needing IRSA.
