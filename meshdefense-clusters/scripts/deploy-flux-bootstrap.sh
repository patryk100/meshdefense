#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script: deploy-flux-bootstrap.sh
# Purpose: Declarative Flux v2 Bootstrap & In-Cluster OCI Secret Provider (Story 2.5)
#          Wires Flux v2 to private ECR via IRSA and External Secrets Operator
#          for zero-plaintext GitOps secret resolution in an air-gapped enclave.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MANIFESTS_DIR="${REPO_ROOT}/manifests/flux-system"

source "${SCRIPT_DIR}/meshdefense-env.sh"

echo "=========================================================="
echo " Starting Declarative Flux v2 Airgap GitOps Bootstrap"
echo " AWS Account: ${AWS_ACCOUNT_ID} | Region: ${AWS_REGION} | Env: ${ENVIRONMENT}"
echo "=========================================================="

# 1. Apply Flux v2 CRDs & Namespace
echo "==> [1/5] Applying Flux v2 CustomResourceDefinitions..."
kubectl apply -f "${MANIFESTS_DIR}/01-crds.yaml"

# 2. Apply Flux v2 Controllers (Source, Helm, Kustomize, Notification)
echo "==> [2/5] Deploying Flux v2 Controllers configured with IRSA..."
cat "${MANIFESTS_DIR}/02-controllers.yaml" | apply_parameterized_manifest | kubectl apply -f -

# 3. Wait for Flux Controllers rollout
echo "==> [3/5] Waiting for controller deployments to rollout..."
kubectl rollout status deployment/source-controller -n flux-system --timeout=120s
kubectl rollout status deployment/kustomize-controller -n flux-system --timeout=120s
kubectl rollout status deployment/helm-controller -n flux-system --timeout=120s

# 4. Deploy ESO in-cluster secret synchronization
echo "==> [4/5] Synchronizing GitOps credentials via External Secrets Operator..."
kubectl apply -f "${MANIFESTS_DIR}/03-flux-externalsecrets.yaml"

# 5. Configure Declarative OCI Repository reconciliation
echo "==> [5/5] Configuring Declarative OCI Repository Sync..."
cat "${MANIFESTS_DIR}/04-oci-repository-sync.yaml" | apply_parameterized_manifest | kubectl apply -f -

echo "=========================================================="
echo " [OK] Flux v2 GitOps Bootstrap successfully deployed!"
echo "=========================================================="
