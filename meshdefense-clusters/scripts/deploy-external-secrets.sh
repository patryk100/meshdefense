#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script: deploy-external-secrets.sh
# Purpose: Deploys External Secrets Operator (ESO) and registers AWS Secrets Manager
#          ClusterSecretStore in an air-gapped / private EKS enclave using IRSA.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MANIFESTS_DIR="${REPO_ROOT}/manifests/external-secrets"

echo "==> Deploying External Secrets Operator to EKS..."

# 1. Apply namespace
echo "==> Applying namespace..."
kubectl apply -f "${MANIFESTS_DIR}/00-namespace.yaml"

# 2. Apply Custom Resource Definitions
echo "==> Applying Custom Resource Definitions (CRDs)..."
kubectl apply -f "${MANIFESTS_DIR}/01-crds.yaml"

# 3. Apply Operator manifests (Deployment, RBAC, IRSA ServiceAccount)
echo "==> Applying Operator Deployment and RBAC..."
kubectl apply -f "${MANIFESTS_DIR}/02-operator.yaml"

# 4. Wait for controller deployment rollout
echo "==> Waiting for External Secrets Operator deployment rollout..."
kubectl rollout status deployment/external-secrets -n external-secrets --timeout=120s

# 5. Apply ClusterSecretStore
echo "==> Configuring ClusterSecretStore for AWS Secrets Manager..."
kubectl apply -f "${MANIFESTS_DIR}/03-cluster-secret-store.yaml"

echo "==> Validating ClusterSecretStore status..."
sleep 5
kubectl get clustersecretstore aws-secretsmanager

echo "==> External Secrets Operator deployment complete!"
