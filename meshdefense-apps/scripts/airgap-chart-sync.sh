#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# MeshDefense: Push Vendored Application Charts to Internal Harbor OCI Registry
# ==============================================================================

INTERNAL_REGISTRY="${1:-registry.il6.meshdefense.internal}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="$SCRIPT_DIR/../packages"

echo "=========================================================="
echo " Syncing Application Helm Charts to Internal OCI Registry"
echo " Target: oci://$INTERNAL_REGISTRY/charts"
echo "=========================================================="

for pkg in "$PACKAGES_DIR"/*; do
  [[ -d "$pkg" ]] || continue
  PKG_NAME=$(basename "$pkg")
  echo "[*] Processing package: $PKG_NAME..."
  if [[ -f "$pkg/Chart.yaml" ]]; then
    helm package "$pkg" --destination /tmp
    CHART_TAR=$(ls -t /tmp/${PKG_NAME}-*.tgz | head -n 1)
    helm push "$CHART_TAR" "oci://$INTERNAL_REGISTRY/charts"
    rm -f "$CHART_TAR"
  fi
done

echo "=========================================================="
echo " [OK] Application charts synced to internal registry."
echo "=========================================================="
