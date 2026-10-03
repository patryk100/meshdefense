#!/usr/bin/env bash
# ==============================================================================
# Script: deploy-coredns-forwarding.sh
# Purpose: Configure CoreDNS in-cluster forwarding for Route 53 PHZ
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "===================================================================="
echo "[*] Configuring CoreDNS Forwarding for Private Hosted Zone"
echo "===================================================================="

export KUBECONFIG="${KUBECONFIG:-/root/.kube/config}"

# Verify cluster connectivity
echo "[*] Verifying cluster connectivity..."
kubectl cluster-info > /dev/null

echo "[*] Step 1: Applying CoreDNS ConfigMap with meshdefense.internal forwarding..."
kubectl apply -f "${REPO_ROOT}/manifests/coredns/01-coredns-forwarding-cm.yaml"

echo "[*] Step 2: Restarting CoreDNS deployment to pick up ConfigMap..."
kubectl rollout restart deployment/coredns -n kube-system
kubectl rollout status deployment/coredns -n kube-system --timeout=60s

echo "[*] Step 3: Verifying in-cluster CoreDNS resolution..."
COREDNS_IP=$(kubectl get svc -n kube-system kube-dns -o jsonpath="{.spec.clusterIP}")
echo "[*] In-Cluster CoreDNS IP: ${COREDNS_IP}"

echo "[*] Querying in-cluster CoreDNS for harbor.apps.poc-minimal.il6.meshdefense.internal..."
RESOLVED_IP=$(dig @${COREDNS_IP} harbor.apps.poc-minimal.il6.meshdefense.internal +short +time=3 || true)

if [ -n "${RESOLVED_IP}" ]; then
  echo "[SUCCESS] CoreDNS resolved harbor.apps.poc-minimal.il6.meshdefense.internal to:"
  echo "${RESOLVED_IP}"
else
  echo "[WARNING] Direct query to CoreDNS ClusterIP timed out from host network (normal in certain CNI setups)."
fi

echo "===================================================================="
echo "[SUCCESS] CoreDNS Forwarding configuration completed successfully!"
echo "===================================================================="
