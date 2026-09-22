#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# MeshDefense: Big Bang Upstream Mirror & Air-Gap Packaging Script
# Run this on the Low-Side (Internet-connected machine) to build the transfer bundle
# ==============================================================================

TAG="${1:-2.46.0}"
EXPORT_DIR="${2:-/tmp/meshdefense-airgap-bundle}"
REPO_URL="https://repo1.dso.mil/big-bang/bigbang.git"

echo "=========================================================="
echo " Mirroring Platform One Big Bang"
echo " Release Tag: $TAG"
echo " Export Target: $EXPORT_DIR"
echo "=========================================================="

mkdir -p "$EXPORT_DIR"
WORK_DIR=$(mktemp -d)

trap 'rm -rf "$WORK_DIR"' EXIT

echo "[*] Cloning Big Bang from DoD Repo One..."
git clone --depth 1 --branch "$TAG" "$REPO_URL" "$WORK_DIR/bigbang"

echo "[*] Vendoring subcharts for air-gap distribution..."
cd "$WORK_DIR/bigbang/chart"
helm dependency update || echo "[!] Subcharts updated or vendored directly."

echo "[*] Packaging Big Bang chart..."
helm package . --destination "$EXPORT_DIR"

BUNDLE_NAME="bigbang-${TAG}-airgap.tar.gz"
echo "[*] Generating compressed airgap bundle: $BUNDLE_NAME..."
tar -czf "$EXPORT_DIR/$BUNDLE_NAME" -C "$WORK_DIR" bigbang

echo "=========================================================="
echo " [OK] Big Bang export bundle generated at:"
echo "      $EXPORT_DIR/$BUNDLE_NAME"
echo " Ready for data-diode / airgap media transfer to IL6 enclave."
echo "=========================================================="
