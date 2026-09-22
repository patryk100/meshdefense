# Anchore Grype Package (Air-Gapped Vulnerability Scanner)

Grype performs local container vulnerability scanning against Iron Bank images and custom workload images inside the IL6 enclave.
- **Offline Scanning**: Grype's internal auto-updater is disabled.
- **Database Injection**: Vulnerability databases are updated via the offline sync script (`scripts/update-vuln-db.sh`).
