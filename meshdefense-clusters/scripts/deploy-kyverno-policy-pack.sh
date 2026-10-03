#!/usr/bin/env bash
# ==============================================================================
# MeshDefense: Deploy Kyverno NIST 800-53 Policy Pack & Admission Event Streamer
# Compliant with DoD IL6 and NIST 800-53 (AC-3, CM-7, SI-7, AU-2, AU-3, AU-6)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}======================================================================${NC}"
echo -e "${CYAN}${BOLD} MeshDefense: Deploying Kyverno NIST 800-53 Policy Pack & Streamer    ${NC}"
echo -e "${CYAN}${BOLD}======================================================================${NC}"

if ! command -v kubectl &> /dev/null; then
  echo -e "${RED}[-] kubectl is required but not installed. Aborting.${NC}"
  exit 1
fi

source "${SCRIPT_DIR}/meshdefense-env.sh"

echo -e "    AWS Account: ${GREEN}${AWS_ACCOUNT_ID}${NC} | Region: ${GREEN}${AWS_REGION}${NC} | Env: ${GREEN}${ENVIRONMENT}${NC}"

KYVERNO_MANIFESTS_DIR="${REPO_ROOT}/meshdefense-clusters/manifests/kyverno"

# Step 1: Install Kyverno CRDs
echo -e "[*] Step 1: Installing Kyverno CustomResourceDefinitions..."
kubectl apply -f "${KYVERNO_MANIFESTS_DIR}/01-crds.yaml"

# Step 2: Apply Admission Controller & Policy Pack via Kustomize
echo -e "[*] Step 2: Applying Kyverno admission controller, event streamer, and policies..."
kubectl kustomize "${KYVERNO_MANIFESTS_DIR}" | apply_parameterized_manifest | kubectl apply -f -

# Step 3: Validate Policy Admission Rules
echo -e "[*] Step 3: Verifying active NIST 800-53 ClusterPolicies..."
kubectl get clusterpolicy

echo ""
echo -e "${GREEN}${BOLD}[+] Kyverno NIST 800-53 Policy Pack & Admission Streamer Deployed!${NC}"
echo -e "----------------------------------------------------------------------"
echo -e "  Policy Pack:   NIST 800-53 Controls AC-3, CM-7, SI-7 (STRICT ENFORCE)"
echo -e "  Telemetry:     Structured JSON Audit Event Streaming (AU-2, AU-3, AU-6)"
echo -e "  Admission Gate:Blocking non-root, privilege escalation, host namespaces,"
echo -e "                 and unsigned Iron Bank container images"
echo -e "  cATO Ingest:   Ready for Fluent-Bit / Vector SIEM normalization"
echo -e "======================================================================"
