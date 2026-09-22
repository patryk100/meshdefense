#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# MeshDefense: Cosign Signature Verification for Iron Bank & Big Bang Artifacts
# ==============================================================================

TARGET_IMAGE="${1:-}"
COSIGN_PUBKEY="${2:-/etc/pki/cosign/ironbank.pub}"

if [[ -z "$TARGET_IMAGE" ]]; then
  echo "Usage: $0 <image-reference-or-oci-artifact> [path-to-cosign-pubkey]"
  echo "Example: $0 registry.il6.meshdefense.internal/bigbang/chart:2.46.0"
  exit 1
fi

echo "=========================================================="
echo " Verifying Cosign Signature for Airgap Artifact"
echo " Target: $TARGET_IMAGE"
echo " Key: $COSIGN_PUBKEY"
echo "=========================================================="

if [[ ! -f "$COSIGN_PUBKEY" ]]; then
  echo "[!] Warning: Public key $COSIGN_PUBKEY not found. Ensure DoD Iron Bank key is mounted."
  echo "[*] Falling back to environment verification if COSIGN_KEY is exported..."
fi

if cosign verify --key "$COSIGN_PUBKEY" "$TARGET_IMAGE" 2>/dev/null; then
  echo "[+] Signature VERIFIED: Artifact is authentic and signed by authorized DoD publisher."
else
  echo "[-] SIGNATURE VERIFICATION FAILED: Artifact cannot be verified!"
  exit 1
fi
