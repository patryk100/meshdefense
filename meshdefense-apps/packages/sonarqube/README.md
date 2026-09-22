# SonarQube Package (Air-Gapped SAST)

SonarQube static code analysis package configured for Big Bang.
- **Image Source**: DoD Iron Bank (`ironbank/sonarsource/sonarqube`)
- **Database**: Air-gapped PostgreSQL instance using Iron Bank hardened image
- **Network Policy**: Enforces zero-trust egress, allowing ingress only via Istio gateway
