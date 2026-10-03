# HashiCorp Vault Package (Air-Gapped Secrets & PKI)

Vault provides dynamic secrets, database credentials, PKI certificate issuing, and integration with SOPS for GitOps workflows in the IL6 enclave.
- **Auto-Unseal**: Leverages cloud KMS CMKs (AWS KMS, Azure Key Vault, or GCP Cloud KMS) via private VPC endpoints and EKS IRSA authentication (`arn:aws:iam::...:role/...-irsa-vault`).
- **Raft Storage**: Embedded HA consensus engine (3 replicas) without external database or stateful storage dependencies.
- **Zero-Trust Networking**: STRICT mTLS, restricted NetworkPolicies isolating Raft port 8201 and API port 8200, and Cert-Manager issued TLS certificate.

### Deployment & Validation
```bash
meshdefense-clusters/scripts/deploy-vault-kms-raft.sh
```

