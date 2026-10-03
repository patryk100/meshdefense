#!/usr/bin/env bash
# ==============================================================================
# Script: deploy-cert-manager.sh
# Purpose: Deploy Cert-Manager and configure Air-Gapped PKI / ClusterIssuer
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "===================================================================="
echo "[*] Deploying Cert-Manager & Air-Gapped PKI Integration"
echo "===================================================================="

export KUBECONFIG="${KUBECONFIG:-/root/.kube/config}"

source "${SCRIPT_DIR}/meshdefense-env.sh"

# Step 1: Deploy Cert-Manager core components & CRDs
echo "[*] Step 1: Deploying Cert-Manager CRDs and controllers from private ECR..."
echo "    Registry: ${REGISTRY_DOMAIN}"
cat "${REPO_ROOT}/manifests/cert-manager/01-cert-manager.yaml" | apply_parameterized_manifest | kubectl apply -f -

echo "[*] Step 2: Waiting for Cert-Manager pods to become ready..."
kubectl rollout status deployment/cert-manager -n cert-manager --timeout=120s
kubectl rollout status deployment/cert-manager-cainjector -n cert-manager --timeout=120s
kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=120s

# Allow webhook endpoints to register
echo "[*] Sleeping 10s to ensure webhook endpoint registration..."
sleep 10

# Step 2: Deploy Root and Intermediate PKI Hierarchy & ClusterIssuer
echo "[*] Step 3: Configuring Air-Gapped Root & Intermediate PKI ClusterIssuers..."
kubectl apply -f "${REPO_ROOT}/manifests/cert-manager/02-cluster-issuers.yaml"

echo "[*] Waiting for Root & Intermediate CA certificates to be ready..."
kubectl wait --for=condition=Ready certificate/meshdefense-root-ca -n cert-manager --timeout=60s
kubectl wait --for=condition=Ready certificate/meshdefense-intermediate-ca -n cert-manager --timeout=60s

# Step 3: Deploy Istio Ingress mTLS / TLS certificate
echo "[*] Step 4: Issuing Istio Ingress Gateway TLS certificate (90-day validity, 30-day rotation)..."
kubectl apply -f "${REPO_ROOT}/manifests/cert-manager/03-ingress-wildcard-cert.yaml"

echo "[*] Waiting for Istio Ingress Gateway certificate issuance..."
kubectl wait --for=condition=Ready certificate/istio-ingressgateway-certs -n istio-system --timeout=60s

echo "[*] Step 5: Verifying issued certificates & ClusterIssuers..."
kubectl get clusterissuers.cert-manager.io
kubectl get certificates -A
kubectl get secret -n istio-system istio-ingressgateway-certs -o yaml | grep "tls.crt:" -A 1

echo "===================================================================="
echo "[SUCCESS] Cert-Manager & Air-Gapped PKI successfully configured!"
echo "===================================================================="
