#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# MeshDefense: Air-Gap Cluster Bootstrap Script
# Bootstraps internal CA certs, imagePullSecrets, and installs Flux v2 in offline mode.
# ==============================================================================

ENVIRONMENT="${1:-dev}"
HARBOR_REGISTRY="${2:-registry.il6.meshdefense.internal}"
HARBOR_SECRET_NAME="harbor-registry-secret"

echo "=========================================================="
echo " Bootstrapping Air-Gap Kubernetes for Environment: $ENVIRONMENT"
echo " Internal OCI Registry: $HARBOR_REGISTRY"
echo "=========================================================="

# 1. Verify cluster connection
echo "[*] Checking kubectl connection..."
kubectl cluster-info

# 2. Create core namespaces
echo "[*] Ensuring foundation namespaces exist..."
for ns in flux-system bigbang harbor istio-system logging monitoring; do
  kubectl get ns "$ns" > /dev/null 2>&1 || kubectl create ns "$ns"
done

# 3. Create harbor imagePullSecret in core namespaces if secret credentials are provided
if [[ -n "${REGISTRY_USER:-}" && -n "${REGISTRY_PASS:-}" ]]; then
  echo "[*] Creating registry secret in core namespaces..."
  for ns in flux-system bigbang istio-system logging monitoring; do
    kubectl create secret docker-registry "$HARBOR_SECRET_NAME" \
      --docker-server="$HARBOR_REGISTRY" \
      --docker-username="$REGISTRY_USER" \
      --docker-password="$REGISTRY_PASS" \
      --namespace="$ns" \
      --dry-run=client -o yaml | kubectl apply -f -
  done
  echo "[+] Registry credentials injected."
else
  echo "[i] REGISTRY_USER and REGISTRY_PASS not set. Skipping automated secret creation."
fi

# 4. Install Flux v2 CRDs from local bundle if available
FLUX_BUNDLE_PATH="/opt/airgap/flux/flux-manifests.yaml"
if [[ -f "$FLUX_BUNDLE_PATH" ]]; then
  echo "[*] Installing Flux v2 from offline bundle: $FLUX_BUNDLE_PATH"
  kubectl apply -f "$FLUX_BUNDLE_PATH"
else
  echo "[i] Offline flux bundle not found at $FLUX_BUNDLE_PATH. Ready for GitOps overlay bootstrap."
fi

echo "=========================================================="
echo " [OK] Cluster bootstrap completed for $ENVIRONMENT"
echo "=========================================================="
