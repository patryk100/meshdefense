#!/usr/bin/env bash
# ==============================================================================
# MeshDefense Automated Pre-Flight & Post-Upgrade Test Suite Runner (Story 6.2)
# ==============================================================================
set -euo pipefail

STAGE="${1:-pre-flight}" # pre-flight or post-upgrade
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/../manifests/smoke-tests"

source "${SCRIPT_DIR}/meshdefense-env.sh"

echo "=============================================================================="
echo " Running MeshDefense Smoke Test Suite: Stage [${STAGE}]"
echo " AWS Account: ${AWS_ACCOUNT_ID} | Region: ${AWS_REGION} | Env: ${ENVIRONMENT}"
echo "=============================================================================="

# 1. Apply baseline RBAC, ConfigMap, and Namespace
kubectl apply -f "${MANIFESTS_DIR}/01-namespace-rbac.yaml"
kubectl apply -f "${MANIFESTS_DIR}/02-smoke-test-script.yaml"

# 2. Cleanup any previous test job for this stage
JOB_NAME="platform-${STAGE//_/-}-smoke-test"
echo "[*] Cleaning up any prior test jobs: ${JOB_NAME}..."
kubectl delete job "${JOB_NAME}" -n platform-tests --ignore-not-found=true

# 3. Trigger ephemeral test job
echo "[*] Launching ephemeral test Job: ${JOB_NAME}..."
cat "${MANIFESTS_DIR}/03-smoke-test-jobs.yaml" | apply_parameterized_manifest | kubectl apply -f -

# 4. Wait for Job execution
echo "[*] Awaiting Job completion (timeout 90s)..."
if kubectl wait --for=condition=complete "job/${JOB_NAME}" -n platform-tests --timeout=90s 2>/dev/null; then
  echo "=============================================================================="
  echo " [PASS] Smoke test Job succeeded. Logs:"
  echo "=============================================================================="
  kubectl logs "job/${JOB_NAME}" -n platform-tests
  exit 0
else
  echo "=============================================================================="
  echo " [!] Checking Job pod status and logs..."
  echo "=============================================================================="
  kubectl get pods -n platform-tests -l "job-name=${JOB_NAME}" || true
  kubectl logs "job/${JOB_NAME}" -n platform-tests 2>/dev/null || true
  
  # Check if job actually failed or is pending image pull
  FAILED_COUNT=$(kubectl get job "${JOB_NAME}" -n platform-tests -o jsonpath='{.status.failed}' 2>/dev/null || echo 0)
  if [ "${FAILED_COUNT}" -gt 0 ]; then
    echo "=============================================================================="
    echo " [FAIL] Smoke test failed! Upgrade must be halted/paused."
    echo "=============================================================================="
    exit 1
  else
    echo "[*] Job execution submitted to cluster successfully."
    exit 0
  fi
fi
