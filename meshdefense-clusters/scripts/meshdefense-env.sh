#!/usr/bin/env bash
# ==============================================================================
# MeshDefense: Dynamic Enclave Environment & Account Discovery Helper
# ==============================================================================
# Dynamically resolves AWS Account ID, Region, Cluster Name, and Enclave details.
# Supports deployment across commercial, AWS GovCloud, and DoD IL6 ISOB enclaves
# without hardcoded ARNs, Account IDs, or partition names.
# ==============================================================================

# 1. AWS Account ID resolution (via STS caller identity or environment override)
if [[ -z "${AWS_ACCOUNT_ID:-}" ]]; then
  if command -v aws &> /dev/null; then
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
  fi
fi
export AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-123456789012}"

# 2. AWS Region resolution (via AWS CLI, EC2 metadata, or fallback)
if [[ -z "${AWS_REGION:-}" ]]; then
  if command -v aws &> /dev/null; then
    AWS_REGION=$(aws configure get region 2>/dev/null || echo "")
  fi
  if [[ -z "${AWS_REGION:-}" ]]; then
    AWS_REGION="${AWS_DEFAULT_REGION:-us-gov-west-1}"
  fi
fi
export AWS_REGION

# 3. AWS Partition resolution (aws, aws-us-gov, or aws-iso/aws-iso-b for IL6/SC)
if [[ -z "${AWS_PARTITION:-}" ]]; then
  case "${AWS_REGION}" in
    us-gov-*)
      AWS_PARTITION="aws-us-gov"
      ;;
    *-iso-b-*|us-isob-*)
      AWS_PARTITION="aws-iso-b"
      ;;
    *-iso-*)
      AWS_PARTITION="aws-iso"
      ;;
    *)
      AWS_PARTITION="aws"
      ;;
  esac
fi
export AWS_PARTITION

# 4. Target Environment resolution
export ENVIRONMENT="${ENVIRONMENT:-poc-minimal}"

# 5. Cluster Name resolution
if [[ -z "${CLUSTER_NAME:-}" ]]; then
  if command -v kubectl &> /dev/null; then
    CURRENT_CTX=$(kubectl config current-context 2>/dev/null || echo "")
    if [[ -n "${CURRENT_CTX}" ]]; then
      # Extract cluster name if context contains arn or cluster identifier
      CLUSTER_NAME=$(echo "${CURRENT_CTX}" | awk -F'/' '{print $NF}' | tr -cd '[:alnum:]-_')
    fi
  fi
  CLUSTER_NAME="${CLUSTER_NAME:-meshdefense-${ENVIRONMENT}-eks}"
fi
export CLUSTER_NAME

# 6. Primary OCI Container Registry domain resolution
export REGISTRY_DOMAIN="${REGISTRY_DOMAIN:-${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com}"

# 7. Helper for applying Kustomize or YAML with dynamic environment substitution
apply_parameterized_manifest() {
  export AWS_ACCOUNT_ID AWS_REGION AWS_PARTITION ENVIRONMENT CLUSTER_NAME REGISTRY_DOMAIN VPC_ID="${VPC_ID:-}"
  if ! command -v envsubst &> /dev/null; then
    # Portable Python substitute supporting ${VAR} and ${VAR:-default}
    python3 -c '
import os, sys, re
pattern = re.compile(r"\$\{([A-Za-z0-9_]+)(?::-([^}]*))?\}")
def replace(match):
    var = match.group(1)
    default_val = match.group(2) if match.group(2) is not None else ""
    val = os.environ.get(var)
    if val:
        return val
    elif default_val != "":
        return default_val
    return ""
content = sys.stdin.read()
sys.stdout.write(pattern.sub(replace, content))
'
  else
    python3 -c '
import os, sys, re
pattern = re.compile(r"\$\{([A-Za-z0-9_]+)(?::-([^}]*))?\}")
def replace(match):
    var = match.group(1)
    default_val = match.group(2) if match.group(2) is not None else ""
    val = os.environ.get(var)
    if val:
        return val
    elif default_val != "":
        return default_val
    return ""
content = sys.stdin.read()
sys.stdout.write(pattern.sub(replace, content))
'
  fi
}
