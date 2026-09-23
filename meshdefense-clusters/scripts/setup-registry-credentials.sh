#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# MeshDefense: Setup Registry Credentials for Platform One Big Bang
# Injects registry1.dso.mil (DoD Iron Bank) authentication into the POC cluster
# ==============================================================================

echo "=========================================================="
echo " MeshDefense: Configure Iron Bank (registry1.dso.mil) Auth"
echo "=========================================================="

IRONBANK_USER="${1:-${IRONBANK_USER:-}}"
IRONBANK_PASS="${2:-${IRONBANK_PASS:-}}"

if [[ -z "$IRONBANK_USER" || -z "$IRONBANK_PASS" ]]; then
  echo "Platform One's Iron Bank (registry1.dso.mil) requires basic authentication."
  echo "If you do not have an account, register for free at: https://registry1.dso.mil"
  echo "Obtain your CLI Secret from: User Profile -> CLI secret"
  echo ""
  read -r -p "Enter Iron Bank Username: " IRONBANK_USER
  read -r -s -p "Enter Iron Bank CLI Secret / Password: " IRONBANK_PASS
  echo ""
fi

if [[ -z "$IRONBANK_USER" || -z "$IRONBANK_PASS" ]]; then
  echo "[-] Username and password cannot be empty. Aborting."
  exit 1
fi

echo "[*] Clearing any stale/deadlock admission webhooks..."
kubectl delete validatingwebhookconfiguration gatekeeper-validating-webhook-configuration --ignore-not-found=true
kubectl delete mutatingwebhookconfiguration gatekeeper-mutating-webhook-configuration --ignore-not-found=true

NAMESPACES=("bigbang" "kyverno" "istio-system" "istio-gateway" "monitoring" "argocd")

for ns in "${NAMESPACES[@]}"; do
  echo "[*] Ensuring namespace '$ns' exists and secret is injected..."
  kubectl get namespace "$ns" &>/dev/null || kubectl create namespace "$ns"
  kubectl delete secret private-registry -n "$ns" --ignore-not-found=true
  kubectl create secret docker-registry private-registry \
    --docker-server="registry1.dso.mil" \
    --docker-username="$IRONBANK_USER" \
    --docker-password="$IRONBANK_PASS" \
    --docker-email="${IRONBANK_EMAIL:-user@meshdefense.local}" \
    -n "$ns"
done

echo "[*] Updating Big Bang POC ConfigMap values with Iron Bank credentials..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES_FILE="$SCRIPT_DIR/../../meshdefense-gitops/environments/poc/values-patch.yaml"

python3 -c "
import re, sys
values_path = '$VALUES_FILE'
user = '''$IRONBANK_USER'''
password = '''$IRONBANK_PASS'''

with open(values_path, 'r') as f:
    content = f.read()

# Match any existing registryCredentials block
pattern = r'    registryCredentials:\s*\n\s*-\s*registry:\s*\"?[^\n\"]+\"?\s*\n\s*username:\s*\"?[^\n\"]*\"?\s*\n\s*password:\s*\"?[^\n\"]*\"?\s*\n\s*email:\s*\"?[^\n\"]*\"?'

replacement = f'''    registryCredentials:
      - registry: \"registry1.dso.mil\"
        username: \"{user}\"
        password: \"{password}\"
        email: \"user@meshdefense.local\"'''

new_content, count = re.subn(pattern, replacement, content)
if count > 0:
    with open(values_path, 'w') as f:
        f.write(new_content)
    print('[+] Successfully patched values-patch.yaml with Iron Bank credentials.')
else:
    print('[*] Notice: registryCredentials pattern not matched; manual edit may be needed.')
"

echo "[*] Re-applying POC Kustomize overlay to cluster..."
kubectl apply -k "$SCRIPT_DIR/../../meshdefense-gitops/environments/poc"

echo "[*] Triggering Flux reconciliation for Big Bang..."
kubectl annotate --overwrite helmrelease bigbang -n bigbang reconcile.fluxcd.io/requestedAt="$(date +%s)" 2>/dev/null || true

echo "=========================================================="
echo " [OK] Iron Bank Credentials Configured!"
echo " Monitor deployment progress with:"
echo "   kubectl get pods -A"
echo "   kubectl get helmreleases -A"
echo "=========================================================="
