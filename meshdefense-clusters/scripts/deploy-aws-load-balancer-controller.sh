#!/usr/bin/env bash
# ==============================================================================
# MeshDefense Story 3.2: AWS Load Balancer Controller & Internal NLB Provisioner
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MANIFESTS_DIR="${PROJECT_ROOT}/manifests"

export KUBECONFIG="${KUBECONFIG:-/root/.kube/config}"

echo "===================================================================="
echo "[*] Story 3.2: Deploying AWS Load Balancer Controller & Internal NLB"
echo "===================================================================="

# 1. Apply AWS Load Balancer Controller CRDs
echo -e "\n[*] Step 1: Applying AWS Load Balancer Controller CRDs..."
kubectl apply -f "${MANIFESTS_DIR}/aws-load-balancer-controller/01-crds.yaml"

# 2. Apply AWS Load Balancer Controller TLS Secret, RBAC & Deployment
echo -e "\n[*] Step 2: Deploying AWS Load Balancer Controller with IRSA..."
kubectl apply -f "${MANIFESTS_DIR}/aws-load-balancer-controller/00-tls-secret.yaml"
kubectl apply -f "${MANIFESTS_DIR}/aws-load-balancer-controller/02-controller.yaml"

# 3. Wait for AWS Load Balancer Controller to be ready
echo -e "\n[*] Step 3: Waiting for AWS Load Balancer Controller rollout..."
kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=120s

# 4. Deploy Istio Ingress Gateway & Internal NLB Service
echo -e "\n[*] Step 4: Deploying Istio Ingress Gateway with internal NLB targeting private subnets..."
kubectl apply -f "${MANIFESTS_DIR}/istio-ingress/01-ingress-gateway-nlb.yaml"

# 5. Wait for NLB Service to acquire internal hostname/IP
echo -e "\n[*] Step 5: Waiting for internal NLB provisioning..."
sleep 15
kubectl get svc -n istio-system istio-ingressgateway -o wide

echo -e "\n===================================================================="
echo "[SUCCESS] AWS Load Balancer Controller & Internal NLB deployed successfully!"
echo "===================================================================="
