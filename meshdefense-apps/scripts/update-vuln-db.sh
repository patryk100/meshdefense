#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# MeshDefense: Offline Vulnerability Database Sync for Grype and Trivy
# ==============================================================================

DB_BUNDLE="${1:-/media/transfer/vulnerability-db-latest.tar.gz}"
TARGET_DIR="${2:-/opt/airgap/vuln-db}"

echo "=========================================================="
echo " Updating Air-Gapped Vulnerability Databases"
echo " Bundle: $DB_BUNDLE"
echo " Target: $TARGET_DIR"
echo "=========================================================="

if [[ ! -f "$DB_BUNDLE" ]]; then
  echo "[-] Vulnerability database bundle $DB_BUNDLE not found!"
  exit 1
fi

mkdir -p "$TARGET_DIR"
tar -xzf "$DB_BUNDLE" -C "$TARGET_DIR"

echo "[+] Vulnerability database extracted to $TARGET_DIR."
echo "[+] Scanners (Grype / Trivy) will reference local DB cache."
echo "=========================================================="
