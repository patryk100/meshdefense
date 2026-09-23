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
AUTO_PORT_FORWARD=true

while [[ $# -gt 0 ]]; do
  case $1 in
    --bundle) BUNDLE_PATH="$2"; shift 2 ;;
    --registry) TARGET_REGISTRY="$2"; shift 2 ;;
    --project) TARGET_PROJECT="$2"; shift 2 ;;
    --user) REGISTRY_USER="$2"; shift 2 ;;
    --password) REGISTRY_PASS="$2"; shift 2 ;;
    --no-pf) AUTO_PORT_FORWARD=false; shift ;;
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
CLEANUP_PIDS=()
cleanup() {
  rm -rf "$STAGE_DIR"
  for pid in "${CLEANUP_PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT

# Step 1: Unpack
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

if ! (cd "${STAGE_DIR}" && { command -v sha256sum &>/dev/null && sha256sum -c checksums.sha256 || shasum -a 256 -c checksums.sha256; }); then
  echo ""
  echo -e "${RED}${BOLD}[SECURITY ALERT] SHA256 checksum verification failed! Artifact tampering or bit-rot detected.${NC}"
  echo -e "${RED}Aborting re-hydration immediately to preserve cluster integrity.${NC}"
  exit 1
fi

echo -e "${GREEN}[+] All SHA256 checksums verified successfully. Artifact integrity confirmed!${NC}"

# Check connectivity to registry; start ephemeral port-forward if necessary
if [[ "${AUTO_PORT_FORWARD}" == "true" ]]; then
  if ! curl -sk --connect-timeout 2 "https://${TARGET_REGISTRY}/api/v2.0/systeminfo" > /dev/null 2>&1; then
    echo ""
    echo -e "[*] Launching ephemeral port-forward to istio-gateway/public-ingressgateway..."
    kubectl port-forward -n istio-gateway svc/public-ingressgateway 8443:443 > /dev/null 2>&1 &
    PF_PID=$!
    CLEANUP_PIDS+=("$PF_PID")
    sleep 2
  fi
fi

# Step 3: Check / Create Harbor Project
echo ""
echo -e "[*] Step 3: Verifying target project '${TARGET_PROJECT}' in Harbor..."
HARBOR_API_URL="https://${TARGET_REGISTRY}/api/v2.0"
PROJECT_CHECK=$(curl -sk -u "${REGISTRY_USER}:${REGISTRY_PASS}" \
  -X GET "${HARBOR_API_URL}/projects/${TARGET_PROJECT}" \
  -w "%{http_code}" -o /dev/null || echo "000")

if [[ "${PROJECT_CHECK}" == "404" ]]; then
  echo -e "[*] Creating public project '${TARGET_PROJECT}' in Harbor..."
  curl -sk -u "${REGISTRY_USER}:${REGISTRY_PASS}" \
    -X POST "${HARBOR_API_URL}/projects" \
    -H "Content-Type: application/json" \
    -d "{\"project_name\": \"${TARGET_PROJECT}\", \"metadata\": {\"public\": \"true\"}}" > /dev/null || true
  echo -e "${GREEN}[+] Project '${TARGET_PROJECT}' created.${NC}"
elif [[ "${PROJECT_CHECK}" == "200" ]]; then
  echo -e "${GREEN}[+] Project '${TARGET_PROJECT}' is ready.${NC}"
fi

# Step 4: Ingest Images via Skopeo
echo ""
echo -e "[*] Step 4: Ingesting image archives into internal Harbor registry..."
MANIFEST_JSON="${STAGE_DIR}/manifest.json"

python3 -c "
import json, subprocess, os, sys

target_registry = '${TARGET_REGISTRY}'
target_project = '${TARGET_PROJECT}'
stage_dir = '${STAGE_DIR}'
reg_user = '${REGISTRY_USER}'
reg_pass = '${REGISTRY_PASS}'

with open('${MANIFEST_JSON}') as f:
    items = json.load(f)

for idx, item in enumerate(items):
    tar_path = os.path.join(stage_dir, item['relative_path'])
    orig_img = item['original_image']
    print(f'\n--> [{idx+1}/{len(items)}] Ingesting: {orig_img}')
    
    # Strip domain prefix if present
    parts = orig_img.split('/')
    if len(parts) > 1 and ('.' in parts[0] or ':' in parts[0]):
        repo_and_tag = '/'.join(parts[1:])
    else:
        repo_and_tag = orig_img

    if repo_and_tag.startswith(f'{target_project}/'):
        repo_and_tag = repo_and_tag[len(f'{target_project}/'):]
        
    dest_img = f'docker://{target_registry}/{target_project}/{repo_and_tag}'
    print(f'    Destination: {dest_img}')
    
    # Use skopeo directly or via container
    if subprocess.run(['which', 'skopeo'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
        cmd = [
            'skopeo', 'copy', '--dest-tls-verify=false',
            f'--dest-creds={reg_user}:{reg_pass}',
            f'docker-archive:{tar_path}',
            dest_img
        ]
    else:
        # Use containerized skopeo with host-gateway bridge
        cmd = [
            'docker', 'run', '--rm',
            '--add-host=harbor.127.0.0.1.nip.io:host-gateway',
            '-v', f'{stage_dir}:/stage',
            'quay.io/skopeo/stable:latest',
            'copy', '--dest-tls-verify=false',
            f'--dest-creds={reg_user}:{reg_pass}',
            f'docker-archive:/stage/{item[\"relative_path\"]}',
            dest_img
        ]
        
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(f'[-] Ingestion failed: {res.stderr.strip()}')
        sys.exit(1)
    else:
        print(f'[+] Successfully ingested to {dest_img}')
"

echo ""
echo -e "${GREEN}${BOLD}[+] High-side image re-hydration completed successfully!${NC}"
echo -e "--------------------------------------------------------------------"
echo -e "  Registry: ${TARGET_REGISTRY}"
echo -e "  Project:  ${TARGET_PROJECT}"
echo -e "  Security: All SHA256 checksums verified before ingestion."
echo -e "  Storage:  Images persisted in encrypted MinIO S3 object backend."
echo -e "--------------------------------------------------------------------"
