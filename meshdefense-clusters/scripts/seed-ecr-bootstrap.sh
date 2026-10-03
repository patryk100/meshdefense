#!/usr/bin/env bash
# ==============================================================================
# Script: seed-ecr-bootstrap.sh
# Purpose: Seed ECR Registry & Day-0 Air-Gap Bootstrap Pipeline
#
# Copies minimal bootstrap container images (Cert-Manager, Harbor Operator,
# CoreDNS, kube-proxy, AWS VPC CNI, External Secrets Operator, Flux v2) from
# upstream registries directly into private, KMS-encrypted AWS ECR.
#
# Designed to run from an administrative workstation or CI/CD runner that has
# access to both the public internet and AWS ECR via IAM credentials.
#
# IMPORTANT: EKS add-on images (coredns, kube-proxy, vpc-cni) are sourced from
# the AWS-managed EKS ECR registry (602401143452.dkr.ecr.us-east-1.amazonaws.com).
# These exact versions are pinned to what is currently running on the cluster.
# Update them when upgrading EKS add-on versions.
#
# Once mirrored, the strictly air-gapped zero-IGW EKS cluster pulls exclusively
# via private VPC Interface Endpoints (ecr.api, ecr.dkr, s3 gateway).
# ==============================================================================
set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
# AWS-managed EKS add-on ECR registry (same region)
EKS_ECR_REGISTRY="602401143452.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo -e "${CYAN}${BOLD}====================================================================${NC}"
echo -e "${CYAN}${BOLD} MeshDefense: Day-0 Seed ECR Registry Bootstrap Pipeline            ${NC}"
echo -e "${CYAN}${BOLD} Target ECR  : ${ECR_REGISTRY}                                      ${NC}"
echo -e "${CYAN}${BOLD} Source EKS  : ${EKS_ECR_REGISTRY}                                  ${NC}"
echo -e "${CYAN}${BOLD}====================================================================${NC}"

# ── Authenticate ──────────────────────────────────────────────────────────────
echo -e "\n[*] Authenticating Docker to private ECR (${AWS_REGION})..."
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_REGISTRY}"

echo -e "[*] Authenticating Docker to AWS EKS addon ECR (${AWS_REGION})..."
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${EKS_ECR_REGISTRY}"

# ── Image Matrix ──────────────────────────────────────────────────────────────
# Format: <upstream_image>|<ecr_repo_and_tag>
# EKS add-on images are pinned to versions currently running on meshdefense-poc-minimal-eks (k8s 1.33).
# Update these tags whenever EKS add-on versions are upgraded.
declare -a BOOTSTRAP_IMAGES=(

  # ── Cert-Manager v1.15.3 ─────────────────────────────────────────────────
  "quay.io/jetstack/cert-manager-controller:v1.15.3|cert-manager/cert-manager-controller:v1.15.3"
  "quay.io/jetstack/cert-manager-cainjector:v1.15.3|cert-manager/cert-manager-cainjector:v1.15.3"
  "quay.io/jetstack/cert-manager-webhook:v1.15.3|cert-manager/cert-manager-webhook:v1.15.3"

  # ── GoHarbor v2.10.3 ─────────────────────────────────────────────────────
  "goharbor/harbor-core:v2.10.3|goharbor/harbor-core:v2.10.3"
  "goharbor/harbor-portal:v2.10.3|goharbor/harbor-portal:v2.10.3"
  "goharbor/harbor-registryctl:v2.10.3|goharbor/registry-photon:v2.10.3"
  "goharbor/harbor-db:v2.10.3|goharbor/harbor-db:v2.10.3"
  "goharbor/redis-photon:v2.10.3|goharbor/redis-photon:v2.10.3"
  "goharbor/harbor-jobservice:v2.10.3|goharbor/harbor-jobservice:v2.10.3"
  "goharbor/trivy-adapter-photon:v2.10.3|goharbor/trivy-adapter-photon:v2.10.3"

  # ── EKS Core Networking (sourced from 602401143452 — AWS-managed ECR) ────
  # Pinned to versions running on meshdefense-poc-minimal-eks (EKS 1.33, us-east-1)
  "${EKS_ECR_REGISTRY}/eks/coredns:v1.12.4-eksbuild.38|eks/coredns:v1.12.4-eksbuild.38"
  "${EKS_ECR_REGISTRY}/eks/kube-proxy:v1.30.14-eksbuild.42|eks/kube-proxy:v1.30.14-eksbuild.42"
  "${EKS_ECR_REGISTRY}/amazon-k8s-cni:v1.22.3-eksbuild.1|amazon-k8s-cni:v1.22.3-eksbuild.1"
  "${EKS_ECR_REGISTRY}/amazon-k8s-cni-init:v1.22.3-eksbuild.1|amazon-k8s-cni-init:v1.22.3-eksbuild.1"
  "${EKS_ECR_REGISTRY}/amazon/aws-network-policy-agent:v1.3.7-eksbuild.1|amazon/aws-network-policy-agent:v1.3.7-eksbuild.1"

  # ── External Secrets Operator v0.14.3 ────────────────────────────────────
  "ghcr.io/external-secrets/external-secrets:v0.14.3|external-secrets/external-secrets:v0.14.3"

  # ── Flux v2 GitOps Controllers ───────────────────────────────────────────
  "ghcr.io/fluxcd/source-controller:v1.4.1|fluxcd/source-controller:v1.4.1"
  "ghcr.io/fluxcd/kustomize-controller:v1.4.0|fluxcd/kustomize-controller:v1.4.0"
  "ghcr.io/fluxcd/helm-controller:v1.1.0|fluxcd/helm-controller:v1.1.0"
  "ghcr.io/fluxcd/notification-controller:v1.4.0|fluxcd/notification-controller:v1.4.0"
  "ghcr.io/fluxcd/image-automation-controller:v0.39.0|fluxcd/image-automation-controller:v0.39.0"
  "ghcr.io/fluxcd/image-reflector-controller:v0.33.0|fluxcd/image-reflector-controller:v0.33.0"

  # ── AWS Load Balancer Controller ─────────────────────────────────────────
  "${EKS_ECR_REGISTRY}/amazon/aws-load-balancer-controller:v2.8.2|amazon/aws-load-balancer-controller:v2.8.2"
)

TOTAL="${#BOOTSTRAP_IMAGES[@]}"
COUNT=0
FAILED=0
FAILED_IMAGES=()

echo -e "\n[*] Commencing seeding of ${TOTAL} bootstrap images to ECR..."

for entry in "${BOOTSTRAP_IMAGES[@]}"; do
  COUNT=$((COUNT + 1))
  IFS="|" read -r UPSTREAM_IMAGE TARGET_REPO_TAG <<< "${entry}"
  TARGET_ECR_IMAGE="${ECR_REGISTRY}/${TARGET_REPO_TAG}"

  echo -e "\n[${COUNT}/${TOTAL}] ${YELLOW}${UPSTREAM_IMAGE}${NC}"
  echo -e "         → ${GREEN}${TARGET_ECR_IMAGE}${NC}"

  # Pull upstream image (enforce linux/amd64 for cluster worker node compatibility)
  if ! docker pull --platform linux/amd64 "${UPSTREAM_IMAGE}" --quiet; then
    echo -e "${RED}[!] FAIL: could not pull ${UPSTREAM_IMAGE}${NC}"
    FAILED=$((FAILED + 1))
    FAILED_IMAGES+=("${TARGET_REPO_TAG}")
    continue
  fi

  # Tag for target ECR
  docker tag "${UPSTREAM_IMAGE}" "${TARGET_ECR_IMAGE}"

  # Push to private ECR
  if ! docker push "${TARGET_ECR_IMAGE}" --quiet; then
    echo -e "${RED}[!] FAIL: could not push ${TARGET_ECR_IMAGE}${NC}"
    FAILED=$((FAILED + 1))
    FAILED_IMAGES+=("${TARGET_REPO_TAG}")
    continue
  fi

  # Remove local image to keep disk usage low
  docker rmi "${UPSTREAM_IMAGE}" "${TARGET_ECR_IMAGE}" > /dev/null 2>&1 || true

  echo -e "${GREEN}[+] Seeded ${TARGET_REPO_TAG}${NC}"
done

echo -e "\n${CYAN}${BOLD}====================================================================${NC}"
if [[ ${FAILED} -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}[SUCCESS] All ${TOTAL} bootstrap images mirrored to private ECR!${NC}"
else
  echo -e "${RED}${BOLD}[WARNING] Seeding completed with ${FAILED}/${TOTAL} errors:${NC}"
  for img in "${FAILED_IMAGES[@]}"; do
    echo -e "${RED}  - ${img}${NC}"
  done
fi
echo -e "${CYAN}${BOLD}====================================================================${NC}"
exit ${FAILED}
