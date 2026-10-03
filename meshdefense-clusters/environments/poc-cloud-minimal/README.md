# Cost-Effective Cloud POC Environment (`poc-cloud-minimal`)

This environment provides a cost-conscious, single-AZ infrastructure blueprint for validating the full MeshDefense platform in AWS / AWS GovCloud without incurring enterprise multi-AZ high-availability costs.

---

## 💰 Cost Optimization Highlights

| Optimization | Production (`prod`) | Minimal POC (`poc-cloud-minimal`) | Savings |
| :--- | :--- | :--- | :--- |
| **EKS Architecture** | Multi-AZ Managed Nodes + Karpenter | Single Managed Node Pool (`t3.xlarge` / `t3.2xlarge`) | ~ 75% |
| **RDS PostgreSQL** | Multi-AZ `db.r6g.xlarge` | Single-AZ `db.t4g.small` (burstable ARM) | ~ 85% |
| **Bastion Jumpbox** | Running 24/7 with dedicated EBS | Ephemeral `t3.micro` SSM-only instance | ~ 70% |
| **S3 Lifecycle** | Long-term Glacier tiering (365d) | Accelerated expiration (60d - 90d) | ~ 60% |
| **Estimated Spend** | ~$2,800 / month | ~$380 / month | **~ 86% Reduction** |

---

## 🔒 Parity & Compliance Guarantee

Despite aggressive cost reductions, `poc-cloud-minimal` enforces **100% cryptographic and zero-trust parity** with production:
- **Dedicated 6-Tier KMS Keyring**: Discrete CMKs for Network, EBS, S3, RDS, Secrets Manager, and Kubernetes Secrets.
- **Zero-Ingress Isolated VPC**: Zero default Internet Gateways; private VPC endpoints for S3, ECR, KMS, STS, and CloudWatch.
- **Granular IRSA Factory**: Full OIDC trust architecture with least-privilege IAM roles for Velero, ESO, Vector, Vault, and EBS CSI.
- **Zero Static IAM Keys**: Fully compliant with DoD Cloud SRG IL6 and NIST SP 800-53 Rev 5 controls.

---

## 🚀 Quickstart Deployment

```bash
cd meshdefense-clusters/environments/poc-cloud-minimal

# 1. Initialize Terraform
terraform init

# 2. Review execution plan
terraform plan

# 3. Apply infrastructure
terraform apply -auto-approve

# 4. View provisioned endpoints and role ARNs
terraform output
```

To destroy resources after testing and prevent ongoing cloud spend:
```bash
terraform destroy -auto-approve
```
