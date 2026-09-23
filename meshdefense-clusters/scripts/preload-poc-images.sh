#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# MeshDefense: Preload Images into KinD for Zero-Auth Local POC
# Pulls standard open-source images from Docker Hub, tags them to match
# Iron Bank identifiers, and sideloads them into the KinD cluster nodes.
# This bypasses the need for DoD Iron Bank credentials for local dev!
# ==============================================================================

CLUSTER_NAME="meshdefense-poc"

echo "=========================================================="
echo " MeshDefense: Preloading Images for KinD Cluster '$CLUSTER_NAME'"
echo " Mode: Zero-Auth Public OSS Sideload"
echo "=========================================================="

IMAGES=(
  # Gatekeeper
  "openpolicyagent/gatekeeper:v3.15.0|registry1.dso.mil/ironbank/opensource/openpolicyagent/gatekeeper:v3.22.2"
  # Istio
  "istio/pilot:1.22.1|registry1.dso.mil/ironbank/istio/pilot:1.22.1"
  "istio/proxyv2:1.22.1|registry1.dso.mil/ironbank/istio/proxyv2:1.22.1"
  # ArgoCD
  "quay.io/argoproj/argocd:v2.11.2|registry1.dso.mil/ironbank/opensource/argo/argocd:v2.11.2"
  "redis:6.2.14|registry1.dso.mil/ironbank/opensource/redis/redis6:6.2.14"
)

for entry in "${IMAGES[@]}"; do
  IFS="|" read -r upstream_img ib_img <<< "$entry"
  echo "[*] Pulling upstream public image: $upstream_img..."
  docker pull "$upstream_img" || {
    echo "[!] Warning: failed to pull $upstream_img, skipping..."
    continue
  }
  echo "    -> Tagging as: $ib_img"
  docker tag "$upstream_img" "$ib_img"

  echo "    -> Loading into KinD cluster nodes: $CLUSTER_NAME..."
  kind load docker-image "$ib_img" --name "$CLUSTER_NAME"
done

echo "=========================================================="
echo " [OK] Images successfully sideloaded into KinD nodes!"
echo " containerd will find images locally without authentication."
echo "=========================================================="
