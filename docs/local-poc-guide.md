# MeshDefense Local Cost-Effective POC Guide

This guide describes how to spin up a **zero-cloud-cost local POC** or **low-budget single-node cloud POC** of Platform One's Big Bang on the `poc/local-cost-effective` branch.

---

## Architecture Overview

```
                      DEVELOPER LAPTOP (macOS / Linux)
 +-------------------------------------------------------------------------+
 |                                                                         |
 |  Docker / OrbStack Network: "kind"                                      |
 |                                                                         |
 |  +--------------------------------+   +-------------------------------+ |
 |  | Local Registry                 |   | KinD Kubernetes Cluster       | |
 |  | (meshdefense-registry:5001)    |   | (meshdefense-poc)             | |
 |  +---------------+----------------+   +---------------+---------------+ |
 |                  |                                    |                 |
 |                  +============ OCI Images ===========>|                 |
 |                                                       |                 |
 |  Host Port Forwarding:                                |                 |
 |  - http://localhost:80   ============================>|  Istio Ingress |
 |  - https://localhost:443 ============================>|  Gateway       |
 |  - *.127.0.0.1.nip.io    ============================>|                 |
 +-------------------------------------------------------------------------+
```

---

## 1. Quickstart: Local KinD Cluster (Zero Cloud Cost)

### Prerequisites
- Docker or OrbStack running
- `kind` CLI (`brew install kind`)
- `kubectl` CLI
- `helm` CLI

### Step 1: Spin Up the Cluster & Local Registry
Run the automated lifecycle script from the repository root:
```bash
./meshdefense-clusters/scripts/local-poc-up.sh
```

This will automatically:
1. Start a local OCI Docker registry at `localhost:5001`.
2. Provision a 3-node KinD cluster with ingress ports `80` and `443` bound to your local machine.
3. Configure containerd on the nodes to trust your local registry.
4. Pre-create the namespaces (`flux-system`, `bigbang`, `istio-system`, `monitoring`).
5. Apply the lightweight Big Bang POC Kustomize overlay.

### Step 2: Verify Cluster & Workloads
```bash
# Check cluster nodes
kubectl get nodes -o wide

# Check core namespaces
kubectl get pods -A

# Test DNS resolution (auto-resolves to 127.0.0.1)
ping -c 1 test.127.0.0.1.nip.io
```

### Step 3: Teardown and Cleanup
When you are finished testing:
```bash
./meshdefense-clusters/scripts/local-poc-down.sh
```

---

## 2. Low-Cost Single-Node Cloud Fallback (AWS Spot Tier)

If you need a remote cloud environment rather than running containers locally on your laptop:

1. Navigate to the minimal POC environment:
   ```bash
   cd meshdefense-clusters/environments/poc-cloud-minimal
   ```
2. Copy and customize variables:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
3. Initialize and apply:
   ```bash
   terraform init
   terraform apply
   ```

### Cost Comparison
| Environment | Node Configuration | Estimated Cost / Month |
|---|---|---|
| **Production (`prod`)** | 3 System (`m6i.2xlarge`) + 6 Workload (`m6i.4xlarge`) | **~$3,200 / mo** |
| **Staging (`stg`)** | 3 System (`m6i.2xlarge`) + 3 Workload (`m6i.4xlarge`) | **~$2,100 / mo** |
| **Cloud POC (`poc-cloud-minimal`)** | 1 `t3.xlarge` + 1 `t3.2xlarge` (Spot) | **~$120 / mo (~$0.16/hr)** |
| **Local KinD POC** | Docker on Host | **$0.00** |

---

## 3. Customizing the POC Overlay

The POC overlay is located at [`meshdefense-gitops/environments/poc`](file:///Users/patrykp/Projects/MeshDefense/meshdefense-gitops/environments/poc):

- **Enable Addons**: Open [`values-patch.yaml`](file:///Users/patrykp/Projects/MeshDefense/meshdefense-gitops/environments/poc/values-patch.yaml) and set `addons.sonarqube.enabled = true` or `addons.gitlab.enabled = true`.
- **Adjust Resources**: Memory and CPU requests in `values-patch.yaml` are intentionally set low for local machines.
- **Inspect Rendered Manifests**:
  ```bash
  kustomize build meshdefense-gitops/environments/poc
  ```
