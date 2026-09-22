#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# MeshDefense: Local POC Cleanup Script
# Deletes the KinD cluster and removes the local registry container.
# ==============================================================================

CLUSTER_NAME="meshdefense-poc"
REGISTRY_NAME="meshdefense-registry"

echo "=========================================================="
echo " Tearing Down MeshDefense Local POC Environment"
echo " Cluster: $CLUSTER_NAME"
echo " Registry: $REGISTRY_NAME"
echo "=========================================================="

# 1. Delete KinD cluster
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "[*] Deleting KinD cluster '$CLUSTER_NAME'..."
  kind delete cluster --name "$CLUSTER_NAME"
  echo "[+] Cluster deleted."
else
  echo "[i] KinD cluster '$CLUSTER_NAME' does not exist."
fi

# 2. Stop and remove local registry container
if docker ps -a --format '{{.Names}}' | grep -q "^${REGISTRY_NAME}$"; then
  echo "[*] Stopping and removing registry container '$REGISTRY_NAME'..."
  docker rm -f "$REGISTRY_NAME"
  echo "[+] Registry removed."
else
  echo "[i] Registry '$REGISTRY_NAME' does not exist."
fi

echo "=========================================================="
echo " [OK] Cleanup complete. All local resources removed."
echo "=========================================================="
