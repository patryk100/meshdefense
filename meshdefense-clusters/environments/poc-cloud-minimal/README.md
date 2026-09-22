# Cost-Effective Cloud POC Environment (`poc-cloud-minimal`)

This environment is designed for low-budget, single-node or burstable cloud testing when you need to deploy to AWS/GovCloud without incurring enterprise multi-AZ costs.

## Cost Optimization Highlights
- Single control plane with minimal node count (1 system node + 1 workload node).
- Utilizes burstable / spot instance families (`t3.xlarge` / `t3.2xlarge`).
- Reduces infrastructure spend by **~85%** compared to production multi-AZ clusters.
- Can be spun down immediately after testing.
