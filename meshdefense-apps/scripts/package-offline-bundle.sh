#!/usr/bin/env bash
# ==============================================================================
# MeshDefense: Offline Artifact Bundle Packager (Low-Side Export)
# Pulls container images, packages them, and creates SHA256 cryptographic checksums
# ==============================================================================
set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_LIST="${SCRIPT_DIR}/../images/app-images.txt"
OUTPUT_BUNDLE="/tmp/meshdefense-airgap-bundle.tar.gz"
SINGLE_IMAGE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --file) IMAGE_LIST="$2"; shift 2 ;;
    --image) SINGLE_IMAGE="$2"; shift 2 ;;
    --output) OUTPUT_BUNDLE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo -e "${CYAN}${BOLD}====================================================================${NC}"
echo -e "${CYAN}${BOLD} MeshDefense: Low-Side Offline Artifact Bundle Packager             ${NC}"
echo -e "${CYAN}${BOLD}====================================================================${NC}"

WORK_DIR=$(mktemp -d)
IMAGES_DIR="${WORK_DIR}/images"
mkdir -p "${IMAGES_DIR}"
MANIFEST_FILE="${WORK_DIR}/manifest.json"
CHECKSUM_FILE="${WORK_DIR}/checksums.sha256"

# Cleanup on exit
trap 'rm -rf "$WORK_DIR"' EXIT

echo -e "[*] Staging directory: ${WORK_DIR}"
echo -e "[*] Target bundle:    ${OUTPUT_BUNDLE}"

declare -a TARGET_IMAGES=()
if [[ -n "${SINGLE_IMAGE}" ]]; then
  TARGET_IMAGES+=("${SINGLE_IMAGE}")
elif [[ -f "${IMAGE_LIST}" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Strip comments and whitespace
    img=$(echo "$line" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    [[ -z "$img" ]] && continue
    TARGET_IMAGES+=("$img")
  done < "${IMAGE_LIST}"
else
  echo -e "${RED}[-] No images specified and image list ${IMAGE_LIST} not found!${NC}"
  exit 1
fi

echo -e "[*] Packaging ${#TARGET_IMAGES[@]} image(s)..."
echo "[]" > "${MANIFEST_FILE}"

INDEX=0
for img in "${TARGET_IMAGES[@]}"; do
  echo ""
  echo -e "${YELLOW}[${INDEX}] Exporting:${NC} ${img}"
  
  # Pull image if not already local
  if ! docker image inspect "${img}" > /dev/null 2>&1; then
    echo -e "    Pulling image from upstream registry..."
    docker pull "${img}"
  fi

  SAFE_NAME="img_${INDEX}_$(echo "${img}" | tr '/:@' '___').tar"
  TAR_PATH="${IMAGES_DIR}/${SAFE_NAME}"

  echo -e "    Saving container layer tarball: ${SAFE_NAME}..."
  docker save "${img}" -o "${TAR_PATH}"

  echo -e "    Computing SHA256 cryptographic checksum..."
  (cd "${WORK_DIR}" && shasum -a 256 "images/${SAFE_NAME}" >> "${CHECKSUM_FILE}")

  # Record in manifest
  python3 -c "
import json
with open('${MANIFEST_FILE}', 'r+') as f:
    data = json.load(f)
    data.append({
        'original_image': '${img}',
        'file_name': '${SAFE_NAME}',
        'relative_path': 'images/${SAFE_NAME}'
    })
    f.seek(0)
    json.dump(data, f, indent=2)
"
  INDEX=$((INDEX + 1))
done

# Compute bundle creation metadata
echo ""
echo -e "[*] Finalizing artifact bundle structure..."
cat <<EOF > "${WORK_DIR}/bundle-metadata.json"
{
  "bundle_version": "1.0.0",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "generator": "meshdefense-packager",
  "total_images": ${INDEX}
}
EOF

(cd "${WORK_DIR}" && shasum -a 256 "manifest.json" >> "${CHECKSUM_FILE}")
(cd "${WORK_DIR}" && shasum -a 256 "bundle-metadata.json" >> "${CHECKSUM_FILE}")

mkdir -p "$(dirname "${OUTPUT_BUNDLE}")"
tar -czf "${OUTPUT_BUNDLE}" -C "${WORK_DIR}" manifest.json bundle-metadata.json checksums.sha256 images

echo ""
echo -e "${GREEN}${BOLD}[+] Offline artifact bundle successfully packaged!${NC}"
echo -e "--------------------------------------------------------------------"
echo -e "  Bundle Path: ${OUTPUT_BUNDLE}"
echo -e "  Bundle Size: $(du -sh "${OUTPUT_BUNDLE}" | cut -f1)"
echo -e "  Bundle SHA256: $(shasum -a 256 "${OUTPUT_BUNDLE}" | cut -d' ' -f1)"
echo -e "--------------------------------------------------------------------"
