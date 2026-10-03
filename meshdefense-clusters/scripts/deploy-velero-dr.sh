#!/usr/bin/env bash
# ==============================================================================
# MeshDefense: Deploy Velero Backup & Disaster Recovery Automation
# Enforces AWS Plugin, IRSA Authentication, S3/KMS Encryption, and EBS Snapshots
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MANIFESTS_DIR="${REPO_ROOT}/meshdefense-clusters/manifests/velero"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}====================================================================${NC}"
echo -e "${CYAN}${BOLD} MeshDefense: Deploying Velero Backup & Disaster Recovery (DR)     ${NC}"
echo -e "${CYAN}${BOLD}====================================================================${NC}"

if ! command -v kubectl &> /dev/null; then
  echo -e "${RED}[-] kubectl is required but not installed. Aborting.${NC}"
  exit 1
fi

source "${SCRIPT_DIR}/meshdefense-env.sh"

echo -e "    AWS Account: ${GREEN}${AWS_ACCOUNT_ID}${NC} | Region: ${GREEN}${AWS_REGION}${NC} | Env: ${GREEN}${ENVIRONMENT}${NC}"

echo -e "[*] Step 1: Applying Velero CRDs, RBAC, StorageLocations, and Deployment..."
kubectl kustomize "${MANIFESTS_DIR}" | apply_parameterized_manifest | kubectl apply -f -

echo -e "[*] Step 2: Verifying Velero ServiceAccount IRSA annotations..."
SA_ROLE=$(kubectl get serviceaccount velero -n velero -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null || echo "None")
echo -e "    Velero SA IAM Role: ${GREEN}${SA_ROLE}${NC}"

echo -e "[*] Step 3: Verifying BackupStorageLocation and VolumeSnapshotLocation..."
kubectl get backupstoragelocation -n velero
kubectl get volumesnapshotlocation -n velero

echo -e "[*] Step 4: Verifying Automated Backup Schedules..."
kubectl get schedules -n velero

echo -e "${GREEN}${BOLD}====================================================================${NC}"
echo -e "${GREEN}${BOLD} Velero Backup & Disaster Recovery deployed successfully!          ${NC}"
echo -e "${GREEN}${BOLD}====================================================================${NC}"
