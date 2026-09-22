# Air-Gapped Registry Module (Harbor OCI Registry)

This module deploys a private, enterprise-grade OCI container registry (Harbor) inside the IL6 air-gapped enclave.

## Features
- **OCI Compliance**: Supports container images, Helm charts, and Cosign signature artifacts.
- **Air-Gapped Vulnerability Scanning**: Integrated with Trivy configured in offline mode for scanning Iron Bank and application images.
- **Cloud Object Storage Backend**: Compatible with AWS S3 (GovCloud/C2S), Azure Blob (Gov Secret), and GCP Cloud Storage (GDCH).
