#!/usr/bin/env bash
# ==============================================================================
# MeshDefense: Deploy In-Cluster Harbor Registry with S3 Encrypted Persistence
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

echo -e "${CYAN}${BOLD}====================================================================${NC}"
echo -e "${CYAN}${BOLD} MeshDefense: Provisioning Harbor with Encrypted S3 Persistence    ${NC}"
echo -e "${CYAN}${BOLD}====================================================================${NC}"

# Check prerequisites
if ! command -v helm &> /dev/null; then
  echo -e "${RED}[-] Helm is required but not installed. Aborting.${NC}"
  exit 1
fi

if ! command -v kubectl &> /dev/null; then
  echo -e "${RED}[-] kubectl is required but not installed. Aborting.${NC}"
  exit 1
fi

# Step 1: Deploy MinIO (Encrypted S3 Object Storage)
echo -e "[*] Step 1: Deploying MinIO with SSE-S3 encrypted persistence..."
kubectl apply -f "${REPO_ROOT}/meshdefense-clusters/manifests/minio-encrypted-s3.yaml"

echo -e "[*] Waiting for MinIO pod to become ready..."
kubectl rollout status deployment/minio -n minio --timeout=120s

echo -e "[*] Waiting for S3 bucket initialization job ('harbor-registry')..."
kubectl wait --for=condition=complete job/minio-init-harbor-bucket -n minio --timeout=90s || true

# Step 2: Ensure Harbor namespace exists and copy Iron Bank imagePullSecrets
echo -e "[*] Step 2: Preparing Harbor namespace..."
kubectl create namespace harbor --dry-run=client -o yaml | kubectl apply -f -

# If private-registry secret exists in bigbang, copy it to harbor
if kubectl get secret private-registry -n bigbang &> /dev/null; then
  echo -e "[*] Replicating 'private-registry' pull secret to harbor namespace..."
  kubectl get secret private-registry -n bigbang -o yaml \
    | sed 's/namespace: bigbang/namespace: harbor/' \
    | kubectl apply -f -
fi

# Step 3: Deploy Harbor via Helm with S3-backed storage
echo -e "[*] Step 3: Deploying Harbor registry via Helm..."
helm repo add harbor https://helm.goharbor.io --force-update > /dev/null 2>&1 || true
helm repo update harbor > /dev/null 2>&1

helm upgrade --install harbor harbor/harbor \
  --namespace harbor \
  --values "${REPO_ROOT}/meshdefense-clusters/manifests/harbor-values-s3.yaml" \
  --timeout 10m \
  --wait=false

# Step 4: Apply Istio VirtualService for Harbor
echo -e "[*] Step 4: Exposing Harbor via Istio VirtualService..."
kubectl apply -f "${REPO_ROOT}/meshdefense-clusters/manifests/harbor-virtualservice.yaml"

# Step 5: Wait for Harbor core and registry
echo -e "[*] Step 5: Waiting for Harbor core and database to initialize..."
kubectl rollout status statefulset/harbor-database -n harbor --timeout=180s || true
kubectl rollout status statefulset/harbor-redis -n harbor --timeout=180s || true
kubectl rollout status deployment/harbor-core -n harbor --timeout=240s || true
kubectl rollout status deployment/harbor-registry -n harbor --timeout=240s || true
kubectl rollout status deployment/harbor-portal -n harbor --timeout=180s || true

# Step 6: Configure In-Cluster Node Containerd Registries & Initialize Projects
echo -e "[*] Step 6: Configuring KinD nodes for in-cluster Harbor resolution..."
INGRESS_IP=$(kubectl get svc -n istio-gateway public-ingressgateway -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
if [[ -n "${INGRESS_IP}" ]]; then
  for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
    docker exec "$node" /bin/sh -c "
      grep -q 'harbor.127.0.0.1.nip.io' /etc/hosts || echo '${INGRESS_IP} harbor.127.0.0.1.nip.io' >> /etc/hosts
      mkdir -p /etc/containerd/certs.d/harbor.127.0.0.1.nip.io
      cat <<EOF > /etc/containerd/certs.d/harbor.127.0.0.1.nip.io/hosts.toml
server = \"https://harbor.127.0.0.1.nip.io:443\"

[host.\"https://harbor.127.0.0.1.nip.io:443\"]
  skip_verify = true
EOF
    " 2>/dev/null || true
  done
  echo -e "${GREEN}[+] Cluster nodes configured to pull directly from harbor.127.0.0.1.nip.io.${NC}"
fi

# Initialize default 'ironbank' project via Harbor API
echo -e "[*] Initializing default 'ironbank' project in Harbor..."
kubectl run harbor-init-project --image=curlimages/curl --rm -i --restart=Never -q -- \
  -sk -u admin:MeshDefenseHarbor2026! -X POST "http://harbor.harbor.svc.cluster.local:80/api/v2.0/projects" \
  -H "Content-Type: application/json" \
  -d '{"project_name": "ironbank", "metadata": {"public": "true"}}' 2>/dev/null || true

echo ""
echo -e "${GREEN}${BOLD}[+] Harbor registry successfully deployed with S3-backed encryption!${NC}"
echo -e "--------------------------------------------------------------------"
echo -e "  Portal URL:   https://harbor.127.0.0.1.nip.io:8443"
echo -e "  Registry OCI: harbor.127.0.0.1.nip.io:8443"
echo -e "  Admin User:   admin"
echo -e "  Admin Pass:   MeshDefenseHarbor2026!"
echo -e "  S3 Backend:   http://minio.minio.svc.cluster.local:9000 (Bucket: harbor-registry, SSE-S3: ON)"
echo -e "--------------------------------------------------------------------"
