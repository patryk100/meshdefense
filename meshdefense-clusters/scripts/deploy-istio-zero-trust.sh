#!/usr/bin/env bash
# ==============================================================================
# Script: deploy-istio-zero-trust.sh
# Purpose: Deploy Istio CRDs, Gateway, VirtualServices & STRICT mTLS
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "===================================================================="
echo "[*] Deploying Zero-Trust Istio Gateways, VirtualServices & STRICT mTLS"
echo "===================================================================="

export KUBECONFIG="${KUBECONFIG:-/root/.kube/config}"

# Step 1: Apply Istio CRDs
echo "[*] Step 1: Applying Istio core CRDs (Gateway, VirtualService, PeerAuthentication)..."
kubectl apply -f "${REPO_ROOT}/manifests/istio-core/01-crds.yaml"

# Step 2: Apply mesh-wide and namespace-level STRICT PeerAuthentication
echo "[*] Step 2: Applying STRICT mTLS PeerAuthentication (NIST 800-53 SC-8)..."
kubectl apply -f "${REPO_ROOT}/manifests/istio-core/02-peer-authentication-strict.yaml"

# Step 3: Apply Istio Ingress Gateway with TLS termination
echo "[*] Step 3: Deploying Istio Ingress Gateway terminating TLS using cert-manager certs..."
kubectl apply -f "${REPO_ROOT}/manifests/istio-core/03-ingress-gateway.yaml"

# Step 4: Apply VirtualServices for core platform services
echo "[*] Step 4: Deploying declarative VirtualServices for Big Bang services..."
kubectl apply -f "${REPO_ROOT}/manifests/istio-core/04-platform-virtualservices.yaml"

# Step 5: Verify status
echo "[*] Step 5: Verifying deployed Istio resources..."
kubectl get peerauthentication -A
kubectl get gateway -A
kubectl get virtualservice -A

echo "===================================================================="
echo "[SUCCESS] Zero-Trust Istio Gateways, VS & STRICT mTLS deployed successfully!"
echo "===================================================================="
