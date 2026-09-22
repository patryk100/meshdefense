# Networking & PKI Module (Private DNS & Airgap VPC Endpoints)

This module provisions private DNS zones and VPC Private Interface/Gateway Endpoints required for operating Kubernetes and Big Bang in **disconnected DoD IL6 environments** without NAT Gateways or Internet Gateways.

## Supported Private Endpoints
- **ECR (`ecr.api`, `ecr.dkr`)**: Internal container base image pulls
- **S3 Gateway (`s3`)**: High-speed bucket access for Harbor registry and backup storage
- **KMS (`kms`)**: Secret envelope encryption and decryption operations
- **SSM (`ssm`, `ssmmessages`)**: Secure bastion and node management without public SSH keys
- **STS (`sts`)**: IAM Roles for Service Accounts (IRSA) token validation
