# Keycloak Package (Air-Gapped SSO & DoD PKI)

Keycloak serves as the centralized identity provider and Single Sign-On (SSO) gateway for Big Bang services (GitLab, SonarQube, Grafana, Harbor, NeuVector).
- **Authentication**: Supports DoD CAC / Smart Card PKI authentication and internal OIDC/SAML client federation.
- **State Storage**: Connected to external Multi-AZ RDS PostgreSQL cluster (`postgres.il6.meshdefense.internal`) over encrypted TLS (`sslmode: require`).
- **Perimeter TLS Ingress**: Integrated with Istio ingress gateway via `VirtualService` (`keycloak.apps.*`) with automated 90-day Cert-Manager certificate rotation.
- **Client Realm (`baby-yoda`)**: Pre-configured OIDC clients for:
  - **Harbor** (`harbor-sso`)
  - **Grafana** (`grafana-sso`)
  - **GitLab** (`gitlab-sso`)
  - **NeuVector** (`neuvector-sso`)
- **Hardware Security Tokens (FIDO2 / WebAuthn)**: Configured WebAuthn policy enforcing YubiKey 5 FIPS hardware security keys (`webAuthnPolicyPasswordlessRequireResidentKey: Yes`) for SCIF engineers operating without mobile devices or SMS/TOTP.
- **Local Break-Glass Identity**: Sealed emergency recovery path (`breakglass-admin` / `emergency-breakglass-admin`) for offline disaster recovery and SCIF access (NIST 800-53 IA-2(1), IA-2(2)).

### Deployment & Validation
```bash
meshdefense-clusters/scripts/deploy-keycloak-sso.sh
```


