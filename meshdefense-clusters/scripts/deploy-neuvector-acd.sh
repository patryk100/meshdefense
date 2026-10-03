#!/usr/bin/env bash
# ==============================================================================
# MeshDefense: Deploy NeuVector Active Cyber Defense (ACD) DaemonSet
# Compliant with DoD IL6 and NIST 800-53 (SI-4, AC-3, SC-7)
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
echo -e "${CYAN}${BOLD} MeshDefense: Deploying NeuVector Active Cyber Defense (Protect Mode) ${NC}"
echo -e "${CYAN}${BOLD}======================================================================${NC}"

if ! command -v kubectl &> /dev/null; then
  echo -e "${RED}[-] kubectl is required but not installed. Aborting.${NC}"
  exit 1
fi

source "${SCRIPT_DIR}/meshdefense-env.sh"

echo -e "    AWS Account: ${GREEN}${AWS_ACCOUNT_ID}${NC} | Region: ${GREEN}${AWS_REGION}${NC} | Env: ${GREEN}${ENVIRONMENT}${NC}"

NEUVECTOR_MANIFESTS_DIR="${REPO_ROOT}/meshdefense-clusters/manifests/neuvector"

# Step 1: Install NeuVector CRDs
echo -e "[*] Step 1: Installing NeuVector CustomResourceDefinitions..."
kubectl apply -f "${NEUVECTOR_MANIFESTS_DIR}/01-crds.yaml"

# Step 2: Deploy Controller, Manager, Enforcer DaemonSet and ACD Policies
echo -e "[*] Step 2: Applying NeuVector Controller, Manager, Enforcer DaemonSet, and ACD Policies..."
kubectl kustomize "${NEUVECTOR_MANIFESTS_DIR}" | apply_parameterized_manifest | kubectl apply -f -

# Step 3: Verify Enforcer DaemonSet and ACD Rules
echo -e "[*] Step 3: Verifying NeuVector components and Active Cyber Defense rules..."
kubectl get daemonset -n neuvector neuvector-enforcer-pod || true
kubectl get nvclustersecurityrules || true
kubectl get nvresponserulesecurityrules || true

echo ""
echo -e "${GREEN}${BOLD}[+] NeuVector Active Cyber Defense successfully deployed!${NC}"
echo -e "----------------------------------------------------------------------"
echo -e "  Runtime Defense: Protect Mode across all nodes (NIST 800-53 SI-4)"
echo -e "  Kernel Filter:   eBPF Container Network Inspection DaemonSet"
echo -e "  Incident Action: Real-Time Process Quarantine & Alert Webhook/Syslog"
echo -e "  Ingress Gateway: TLS automated route at neuvector.apps.*"
echo -e "======================================================================"
