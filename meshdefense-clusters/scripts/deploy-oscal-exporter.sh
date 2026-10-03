#!/usr/bin/env bash
# ==============================================================================
# MeshDefense Automated OSCAL Exporter Deployment & Trigger Script (Story 5.6)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/meshdefense-env.sh"

echo "=== Deploying Automated OSCAL Exporter Pipeline ==="
echo "    AWS Account: ${AWS_ACCOUNT_ID} | Region: ${AWS_REGION} | Env: ${ENVIRONMENT}"
kubectl kustomize "${MANIFESTS_DIR}" | apply_parameterized_manifest | kubectl apply -f -

echo "=== Triggering Manual OSCAL Assessment Run ==="
kubectl create job --from=cronjob/oscal-exporter oscal-manual-run-$(date +%s) -n cato || true

echo "=== Verifying In-Cluster OSCAL Assessment Results ==="
kubectl get configmap oscal-latest-assessment-results -n cato -o wide || echo "Waiting for job completion..."
