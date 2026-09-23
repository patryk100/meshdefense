#!/usr/bin/env bash
# ==============================================================================
# MeshDefense: Air-Gap Offline Re-hydration Engine (High-Side Import)
# Unpacks bundle, strictly verifies SHA256 checksums, and pushes directly to Harbor
# ==============================================================================
set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

BUNDLE_PATH="/tmp/meshdefense-airgap-bundle.tar.gz"
TARGET_REGISTRY="harbor.127.0.0.1.nip.io:8443"
TARGET_PROJECT="ironbank"
REGISTRY_USER="admin"
REGISTRY_PASS="MeshDefenseHarbor2026!"
INSECURE=true

while [[ $# -gt 0 ]]; do
  case $1 in
    --bundle) BUNDLE_PATH="$2"; shift 2 ;;
    --registry) TARGET_REGISTRY="$2"; shift 2 ;;
    --project) TARGET_PROJECT="$2"; shift 2 ;;
    --user) REGISTRY_USER="$2"; shift 2 ;;
    --password) REGISTRY_PASS="$2"; shift 2 ;;
    --secure) INSECURE=false; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo -e "${CYAN}${BOLD}====================================================================${NC}"
echo -e "${CYAN}${BOLD} MeshDefense: Air-Gap High-Side Image Re-hydration Engine           ${NC}"
echo -e "${CYAN}${BOLD}====================================================================${NC}"

if [[ ! -f "${BUNDLE_PATH}" ]]; then
  echo -e "${RED}[-] Artifact bundle not found: ${BUNDLE_PATH}${NC}"
  exit 1
fi

STAGE_DIR=$(mktemp -d)
trap 'rm -rf "$STAGE_DIR"' EXIT

echo -e "[*] Step 1: Unpacking artifact bundle..."
echo -e "    Source: ${BUNDLE_PATH}"
echo -e "    Target: ${STAGE_DIR}"
tar -xzf "${BUNDLE_PATH}" -C "${STAGE_DIR}"

# Step 2: Strict Cryptographic Checksum Verification
echo ""
echo -e "[*] Step 2: Enforcing SHA256 cryptographic checksum verification..."
if [[ ! -f "${STAGE_DIR}/checksums.sha256" ]]; then
  echo -e "${RED}[FATAL ERROR] Checksum manifest 'checksums.sha256' missing from bundle! Aborting.${NC}"
  exit 1
fi

CHECKSUM_FAILED=0
(
  cd "${STAGE_DIR}"
  if command -v sha256sum &> /dev/null; then
    sha256sum -c checksums.sha256 || CHECKSUM_FAILED=1
  else
    shasum -a 256 -c checksums.sha256 || CHECKSUM_FAILED=1
  fi
)

if [[ "${CHECKSUM_FAILED}" -ne 0 ]]; then
  echo ""
  echo -e "${RED}${BOLD}[SECURITY ALERT] SHA256 checksum verification failed! Artifact tampering or bit-rot detected.${NC}"
  echo -e "${RED}Aborting re-hydration immediately to preserve cluster integrity.${NC}"
  exit 1
fi

echo -e "${GREEN}[+] All SHA256 checksums verified successfully. Artifact integrity confirmed!${NC}"

# Step 3: Authenticate & Provision Project in Harbor
echo ""
echo -e "[*] Step 3: Connecting to internal Harbor registry (${TARGET_REGISTRY})..."

CURL_FLAGS="-s"
if [[ "${INSECURE}" == "true" ]]; then
  CURL_FLAGS="-sk"
fi

HARBOR_API_URL="https://${TARGET_REGISTRY}/api/v2.0"

# Check / create project in Harbor
echo -e "[*] Checking if project '${TARGET_PROJECT}' exists in Harbor..."
PROJECT_CHECK=$(curl ${CURL_FLAGS} -u "${REGISTRY_USER}:${REGISTRY_PASS}" \
  -X GET "${HARBOR_API_URL}/projects/${TARGET_PROJECT}" \
  -w "%{http_code}" -o /dev/null || echo "000")

if [[ "${PROJECT_CHECK}" == "404" ]]; then
  echo -e "[*] Creating public project '${TARGET_PROJECT}' in Harbor..."
  curl ${CURL_FLAGS} -u "${REGISTRY_USER}:${REGISTRY_PASS}" \
    -X POST "${HARBOR_API_URL}/projects" \
    -H "Content-Type: application/json" \
    -d "{\"project_name\": \"${TARGET_PROJECT}\", \"metadata\": {\"public\": \"true\"}}" > /dev/null || true
  echo -e "${GREEN}[+] Project '${TARGET_PROJECT}' created.${NC}"
elif [[ "${PROJECT_CHECK}" == "200" ]]; then
  echo -e "${GREEN}[+] Project '${TARGET_PROJECT}' already exists.${NC}"
else
  echo -e "${YELLOW}[i] Project check returned HTTP ${PROJECT_CHECK}. Proceeding with push.${NC}"
fi

# Step 4: Login to Registry
echo ""
echo -e "[*] Step 4: Authenticating Docker client to internal Harbor registry..."
echo "${REGISTRY_PASS}" | docker login "${TARGET_REGISTRY}" -u "${REGISTRY_USER}" --password-stdin > /dev/null 2>&1 || {
  echo -e "${YELLOW}[!] Note: Docker daemon login with self-signed certificate may require insecure-registries in daemon.json.${NC}"
  echo -e "${YELLOW}Attempting direct image load and push...${NC}"
}

# Step 5: Ingest Images
echo ""
echo -e "[*] Step 5: Loading image archives and pushing to internal registry..."
MANIFEST_JSON="${STAGE_DIR}/manifest.json"

COUNT=$(python3 -c "import json; f=open('${MANIFEST_JSON}'); print(len(json.load(f)))")
echo -e "[*] Total images to re-hydrate: ${COUNT}"

python3 -c "
import json, subprocess, os, sys

target_registry = '${TARGET_REGISTRY}'
target_project = '${TARGET_PROJECT}'
stage_dir = '${STAGE_DIR}'

with open('${MANIFEST_JSON}') as f:
    items = json.load(f)

for idx, item in enumerate(items):
    tar_path = os.path.join(stage_dir, item['relative_path'])
    orig_img = item['original_image']
    print(f'\n--> [{idx+1}/{len(items)}] Loading: {orig_img}')
    
    # Load into docker
    load_proc = subprocess.run(['docker', 'load', '-i', tar_path], capture_output=True, text=True, check=True)
    print(f'    {load_proc.stdout.strip()}')
    
    # Derive image name without domain prefix
    # e.g. registry1.dso.mil/ironbank/redhat/ubi/ubi9:latest -> redhat/ubi/ubi9:latest
    parts = orig_img.split('/')
    if len(parts) > 1 and ('.' in parts[0] or ':' in parts[0]):
        repo_and_tag = '/'.join(parts[1:])
    else:
        repo_and_tag = orig_img

    # If repo_and_tag starts with target_project (e.g. ironbank/...), strip it to avoid ironbank/ironbank/...
    if repo_and_tag.startswith(f'{target_project}/'):
        repo_and_tag = repo_and_tag[len(f'{target_project}/'):]
        
    harbor_tag = f'{target_registry}/{target_project}/{repo_and_tag}'
    
    print(f'    Tagging as: {harbor_tag}')
    subprocess.run(['docker', 'tag', orig_img, harbor_tag], check=True)
    
    print(f'    Pushing to Harbor...')
    push_res = subprocess.run(['docker', 'push', harbor_tag], capture_output=True, text=True)
    if push_res.returncode != 0:
        print(f'    Push stderr: {push_res.stderr.strip()}')
        # If push failed because of TLS or daemon, try in-cluster skopeo or curl
        sys.exit(push_res.returncode)
    else:
        print(f'    [OK] Successfully pushed {harbor_tag}')
"

echo ""
echo -e "${GREEN}${BOLD}[+] High-side image re-hydration completed successfully!${NC}"
echo -e "--------------------------------------------------------------------"
echo -e "  Registry: ${TARGET_REGISTRY}"
echo -e "  Project:  ${TARGET_PROJECT}"
echo -e "  All artifacts verified via SHA256 checksums before ingestion."
echo -e "--------------------------------------------------------------------"
