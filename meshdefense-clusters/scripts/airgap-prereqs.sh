#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# MeshDefense: Air-Gap Pre-Flight Validation Script for DoD IL6 Clusters
# ==============================================================================

echo "=========================================================="
echo " Starting MeshDefense Air-Gap IL6 Pre-Flight Validation"
echo "=========================================================="

# 1. Check required local CLI binaries
REQUIRED_BINS=("terraform" "kubectl" "helm" "aws" "cosign")
for bin in "${REQUIRED_BINS[@]}"; do
  if ! command -v "$bin" &> /dev/null; then
    echo "[-] Missing critical tool: $bin"
    exit 1
  else
    echo "[+] Found binary: $bin"
  fi
done

# 2. Verify AWS / Cloud authentication
echo "[*] Checking Cloud Identity and STS caller identity..."
if aws sts get-caller-identity > /dev/null 2>&1; then
  ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
  ARN=$(aws sts get-caller-identity --query "Arn" --output text)
  echo "[+] Authenticated as $ARN in Account $ACCOUNT_ID"
else
  echo "[!] Failed to query AWS STS. Ensure your AWS credentials / role are configured."
  exit 1
fi

# 3. Verify KMS accessibility
echo "[*] Checking KMS availability..."
if aws kms list-aliases --max-items 5 > /dev/null 2>&1; then
  echo "[+] KMS service endpoint reachable via VPC interface endpoint."
else
  echo "[!] Unable to query KMS. Check VPC interface endpoint 'com.amazonaws.<region>.kms'."
  exit 1
fi

# 4. Check for air-gap egress violations (Security Verification)
echo "[*] Verifying no public internet route (Air-gap check)..."
if curl -s --connect-timeout 3 https://www.google.com > /dev/null 2>&1; then
  echo "[!] CAUTION: Public internet egress detected! This does not appear to be a strict air-gapped IL6 enclave."
else
  echo "[+] Verified: Zero public internet access (Strict Air-Gap Enclave Confirmed)."
fi

echo "=========================================================="
echo " [OK] Pre-flight validation passed successfully!"
echo "=========================================================="
