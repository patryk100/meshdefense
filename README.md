# MeshDefense: Air-Gapped DevSecOps Kubernetes Platform for Big Bang

Welcome to the **MeshDefense** multi-repository architecture designed for deploying and operating Platform One's **Big Bang** DevSecOps platform inside disconnected, air-gapped DoD Impact Level 6 (IL6) and classified cloud enclaves.

## Architecture Ecosystem

The platform is partitioned into four decoupled repositories:

| Repository | Purpose | Key Technologies |
|---|---|---|
| [`meshdefense-clusters`](./meshdefense-clusters) | Infrastructure as Code (IaC) for IL6 Cloud Kubernetes | Terraform, AWS EKS (Secret), Azure AKS (Gov Secret), GCP GKE, KMS, Harbor |
| [`meshdefense-bigbang`](./meshdefense-bigbang) | Mirrored Platform One Big Bang Helm Umbrella Chart | Big Bang Helm Chart, Cosign, Iron Bank, Offline Vendoring |
| [`meshdefense-apps`](./meshdefense-apps) | Mirrored Applications, Security Tools & Containers | GitLab, SonarQube, NeuVector, Keycloak, Vault, Skopeo Sync |
| [`meshdefense-gitops`](./meshdefense-gitops) | Flux v2 & Kustomize Environment Overlays | Flux v2, Kustomize, SOPS, Istio, Dev/Test/Stg/Prod Overlays |

---

## High-Level Topology in DoD IL6 Disconnected Enclaves

```
                                  AIR-GAP / DATA DIODE BOUNDARY
 [Low-Side / Internet]                         |              [High-Side / IL6 Enclave]
                                               |
  1. Pull upstream Big Bang chart & Iron Bank  |   2. Ingest bundle through diode / guard
     images using Skopeo / Helm export         |
                                               |   3. Push images to Internal Harbor Registry
                                               |      (meshdefense-apps / scripts)
                                               |
                                               |   4. Push charts & overlays to Internal GitLab
                                               |      (meshdefense-bigbang & meshdefense-gitops)
                                               |
                                               |   5. Provision IL6 Private Kubernetes
                                               |      (meshdefense-clusters: EKS / AKS / GKE)
                                               |
                                               |   6. Bootstrap Flux v2 GitOps Controller
                                               |      (Flux reconciles bigbang-gitrepo & HelmRelease)
                                               |
                                               |   7. Big Bang deploys Istio, NeuVector, Monitoring,
                                               |      and DevSecOps tooling with strict mTLS
```

---

## Quick Navigation

- For provisioning the underlying Kubernetes infrastructure and air-gapped registry: see [`meshdefense-clusters/README.md`](./meshdefense-clusters/README.md).
- For mirroring and packaging the Big Bang chart: see [`meshdefense-bigbang/README.md`](./meshdefense-bigbang/README.md).
- For synchronizing container images and application charts: see [`meshdefense-apps/README.md`](./meshdefense-apps/README.md).
- For configuring GitOps deployments across `dev`, `test`, `stg`, and `prod`: see [`meshdefense-gitops/README.md`](./meshdefense-gitops/README.md).
