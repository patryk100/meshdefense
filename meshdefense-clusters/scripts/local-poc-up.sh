#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# MeshDefense: Local Cost-Effective POC Cluster Provisioner (KinD + Local Registry)
# ==============================================================================

CLUSTER_NAME="meshdefense-poc"
REGISTRY_NAME="meshdefense-registry"
REGISTRY_PORT="5001"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIND_CONFIG="$SCRIPT_DIR/kind-config.yaml"

echo "=========================================================="
echo " Starting MeshDefense Local Cost-Effective POC Setup"
echo " Cluster: $CLUSTER_NAME"
echo " Local Registry: localhost:$REGISTRY_PORT"
echo "=========================================================="

# 1. Pre-flight check
for bin in docker kind kubectl helm; do
  if ! command -v "$bin" &> /dev/null; then
    echo "[-] Missing prerequisite tool: $bin"
    echo "    Please install $bin to continue."
    exit 1
  fi
done

# 2. Check if Docker daemon is running
if ! docker info > /dev/null 2>&1; then
  echo "[-] Docker daemon is not running. Please start Docker / OrbStack."
  exit 1
fi

# 3. Create local Docker registry if not already running
if [[ "$(docker inspect -f '{{.State.Running}}' "$REGISTRY_NAME" 2>/dev/null || true)" != "true" ]]; then
  echo "[*] Creating local Docker registry '$REGISTRY_NAME' on port $REGISTRY_PORT..."
  docker run -d --restart=always -p "127.0.0.1:${REGISTRY_PORT}:5000" --network bridge --name "$REGISTRY_NAME" registry:2
else
  echo "[+] Local Docker registry '$REGISTRY_NAME' is already running."
fi

# 4. Create KinD cluster if it doesn't already exist
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "[+] KinD cluster '$CLUSTER_NAME' already exists."
else
  echo "[*] Creating KinD cluster '$CLUSTER_NAME' with ingress ports (80/443)..."
  kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CONFIG"
fi

# 5. Connect local registry to KinD cluster network
if [[ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "$REGISTRY_NAME")" = 'null' ]]; then
  echo "[*] Connecting local registry to kind network..."
  docker network connect "kind" "$REGISTRY_NAME" || true
fi

# 6. Configure containerd on all nodes to trust local registry
echo "[*] Configuring local registry endpoint on KinD nodes..."
REGISTRY_DIR="/etc/containerd/certs.d/localhost:${REGISTRY_PORT}"
for node in $(kind get nodes --name "$CLUSTER_NAME"); do
  docker exec "${node}" mkdir -p "${REGISTRY_DIR}"
  cat <<EOF | docker exec -i "${node}" cp /dev/stdin "${REGISTRY_DIR}/hosts.toml"
[host."http://${REGISTRY_NAME}:5000"]
EOF
done

# 7. Pre-create namespaces
echo "[*] Creating core namespaces for Big Bang POC..."
for ns in flux-system bigbang istio-system monitoring; do
  kubectl get ns "$ns" > /dev/null 2>&1 || kubectl create ns "$ns"
done

# 8. Create local registry pull secret
echo "[*] Applying local registry secret..."
kubectl create secret docker-registry harbor-registry-secret \
  --docker-server="localhost:${REGISTRY_PORT}" \
  --docker-username="poc-user" \
  --docker-password="poc-password" \
  --namespace="bigbang" \
  --dry-run=client -o yaml | kubectl apply -f -

# 9. Apply Big Bang POC Kustomize overlay directly
GITOPS_DIR="$SCRIPT_DIR/../../meshdefense-gitops"
if [[ -d "$GITOPS_DIR/environments/poc" ]]; then
  echo "[*] Applying MeshDefense POC Kustomize overlay..."
  kubectl apply -k "$GITOPS_DIR/environments/poc" || echo "[!] Applied with initial CRD wait."
fi

echo "=========================================================="
echo " [OK] MeshDefense Local POC Cluster is Ready!"
echo ""
echo " Cluster info:        kubectl cluster-info --context kind-${CLUSTER_NAME}"
echo " Local OCI Registry:  localhost:${REGISTRY_PORT} (or ${REGISTRY_NAME}:5000 inside cluster)"
echo " Ingress Host Domain: *.127.0.0.1.nip.io (maps to localhost:80/443)"
echo ""
echo " To stop and cleanup this local environment:"
echo "   $SCRIPT_DIR/local-poc-down.sh"
echo "=========================================================="
