# HashiCorp Vault Package (Air-Gapped Secrets & PKI)

Vault provides dynamic secrets, database credentials, PKI certificate issuing, and integration with SOPS for GitOps workflows in the IL6 enclave.
- **Auto-Unseal**: Leverages cloud KMS CMKs (AWS KMS, Azure Key Vault, or GCP Cloud KMS).
- **Raft Storage**: Embedded HA consensus engine without external storage dependencies.
