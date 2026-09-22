#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# MeshDefense: Air-Gap Container Image Sync via Skopeo
# Supports Low-Side Export to Archive and High-Side Import to Harbor OCI Registry
# ==============================================================================

MODE="export" # export or import
IMAGE_LIST="../images/ironbank-images.txt"
ARCHIVE_PATH="/tmp/meshdefense-images.tar"
INTERNAL_REGISTRY="registry.il6.meshdefense.internal"

while [[ $# -gt 0 ]]; do
  case $1 in
    --mode) MODE="$2"; shift 2 ;;
    --file) IMAGE_LIST="$2"; shift 2 ;;
    --archive) ARCHIVE_PATH="$2"; shift 2 ;;
    --registry) INTERNAL_REGISTRY="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if ! command -v skopeo &> /dev/null; then
  echo "[-] skopeo is required but not installed. Aborting."
  exit 1
fi

echo "=========================================================="
echo " MeshDefense Air-Gap Image Sync Tool"
echo " Operation Mode: $MODE"
echo " Archive Path:   $ARCHIVE_PATH"
echo "=========================================================="

if [[ "$MODE" == "export" ]]; then
  echo "[*] LOW-SIDE EXPORT: Downloading images from upstream registries..."
  TEMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TEMP_DIR"' EXIT

  while IFS= read -r image || [[ -n "$image" ]]; do
    [[ -z "$image" || "$image" =~ ^# ]] && continue
    echo " -> Exporting image: $image"
    SAFE_NAME=$(echo "$image" | tr '/:' '_')
    skopeo copy "docker://$image" "dir:$TEMP_DIR/$SAFE_NAME"
  done < "$IMAGE_LIST"

  echo "[*] Creating tar archive: $ARCHIVE_PATH..."
  tar -cf "$ARCHIVE_PATH" -C "$TEMP_DIR" .
  echo "[+] Export completed. Size: $(du -sh "$ARCHIVE_PATH" | cut -f1)"

elif [[ "$MODE" == "import" ]]; then
  echo "[*] HIGH-SIDE IMPORT: Ingesting images to internal registry ($INTERNAL_REGISTRY)..."
  if [[ ! -f "$ARCHIVE_PATH" ]]; then
    echo "[-] Archive file $ARCHIVE_PATH not found!"
    exit 1
  fi

  TEMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TEMP_DIR"' EXIT

  echo "[*] Unpacking archive..."
  tar -xf "$ARCHIVE_PATH" -C "$TEMP_DIR"

  for img_dir in "$TEMP_DIR"/*; do
    [[ -d "$img_dir" ]] || continue
    DIRNAME=$(basename "$img_dir")
    # Restore original image path relative to registry
    # e.g., registry1.dso.mil_ironbank_istio_pilot_1.20.2 -> ironbank/istio/pilot:1.20.2
    TARGET_IMAGE=$(echo "$DIRNAME" | sed -E 's/^[^_]+_//' | sed 's/_/\//g' | sed -E 's/(.*)\/(.*)/\1:\2/')
    FULL_TARGET="$INTERNAL_REGISTRY/$TARGET_IMAGE"

    echo " -> Ingesting to: docker://$FULL_TARGET"
    skopeo copy --dest-tls-verify=false "dir:$img_dir" "docker://$FULL_TARGET"
  done
  echo "[+] All images successfully imported to $INTERNAL_REGISTRY."
fi

echo "=========================================================="
echo " [OK] Operation $MODE finished successfully."
echo "=========================================================="
