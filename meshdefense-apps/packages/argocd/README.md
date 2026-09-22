# ArgoCD Package (Air-Gapped Declarative GitOps UI)

ArgoCD provides a declarative, continuous delivery visual console and application orchestrator in the IL6 enclave.

## Highlights
- **Iron Bank Hardened Images**: Sourced from `registry1.dso.mil/ironbank/opensource/argo/argocd`.
- **DoD CAC / Keycloak SSO**: Integrated with Keycloak OIDC for CAC / PKI single sign-on.
- **Istio Gateway Integration**: Exposed securely via Istio mTLS VirtualServices.
- **Role-Based Access Control (RBAC)**: Least-privilege role bindings mapped to Keycloak groups (`admins`, `developers`).
