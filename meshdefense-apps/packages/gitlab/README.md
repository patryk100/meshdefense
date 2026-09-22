# GitLab Package (Air-Gapped DevSecOps)

Mirrored GitLab package configured to run behind the Istio service mesh in Platform One Big Bang.
- **Image Source**: DoD Iron Bank (`ironbank/gitlab/gitlab-ee`)
- **Ingress**: Managed via Big Bang Istio Ingress Gateway with mutual TLS
- **Runners**: Air-gap runner pods pulling UBI9 hardened worker images from local Harbor
