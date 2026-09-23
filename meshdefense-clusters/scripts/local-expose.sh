#!/usr/bin/env bash
# ==============================================================================
# MeshDefense: Local Ingress Gateway Port-Forward & Service Access Helper
# ==============================================================================
set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

PORT_HTTPS="${PORT_HTTPS:-8443}"
PORT_HTTP="${PORT_HTTP:-8080}"

echo -e "${CYAN}${BOLD}==========================================================${NC}"
echo -e "${CYAN}${BOLD} MeshDefense: Exposing Big Bang Services Locally          ${NC}"
echo -e "${CYAN}${BOLD}==========================================================${NC}"

# Fetch credentials dynamically
echo -e "[*] Retrieving admin credentials..."
ARGOCD_PW=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "N/A")
GRAFANA_PW=$(kubectl get secret -n monitoring monitoring-grafana -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d || echo "N/A")
HARBOR_PW=$(kubectl get secret -n harbor harbor-core -o jsonpath='{.data.HARBOR_ADMIN_PASSWORD}' 2>/dev/null | base64 -d || echo "MeshDefenseHarbor2026!")

echo ""
echo -e "${GREEN}${BOLD}Active Services & Access URLs:${NC}"
echo -e "----------------------------------------------------------"
echo -e "  ${BOLD}Harbor Registry:${NC} https://harbor.127.0.0.1.nip.io:${PORT_HTTPS}"
echo -e "    Username:     admin"
echo -e "    Password:     ${YELLOW}${HARBOR_PW}${NC}"
echo -e "    Docker Login: docker login harbor.127.0.0.1.nip.io:${PORT_HTTPS} -u admin -p ${HARBOR_PW}"
echo ""
echo -e "  ${BOLD}ArgoCD:${NC}          https://argocd.127.0.0.1.nip.io:${PORT_HTTPS}"
echo -e "    Username:     admin"
echo -e "    Password:     ${YELLOW}${ARGOCD_PW}${NC}"
echo ""
echo -e "  ${BOLD}Grafana:${NC}         https://grafana.127.0.0.1.nip.io:${PORT_HTTPS}"
echo -e "    Username:     admin"
echo -e "    Password:     ${YELLOW}${GRAFANA_PW}${NC}"
echo ""
echo -e "  ${BOLD}Prometheus:${NC}      https://prometheus.127.0.0.1.nip.io:${PORT_HTTPS}"
echo -e "  ${BOLD}Alertmanager:${NC}    https://alertmanager.127.0.0.1.nip.io:${PORT_HTTPS}"
echo -e "----------------------------------------------------------"
echo -e "${YELLOW}Note:${NC} The ingress gateway uses a self-signed TLS cert (*.127.0.0.1.nip.io)."
echo -e "When prompted by your browser, click 'Advanced' -> 'Proceed to ...'."
echo ""
echo -e "[*] Forwarding ports from istio-gateway/public-ingressgateway..."
echo -e "    Local ${PORT_HTTPS} -> Pod 443 (HTTPS)"
echo -e "    Local ${PORT_HTTP}  -> Pod 80  (HTTP)"
echo -e "Press ${BOLD}Ctrl+C${NC} to stop port-forwarding."
echo ""

exec kubectl port-forward -n istio-gateway svc/public-ingressgateway "${PORT_HTTPS}:443" "${PORT_HTTP}:80"
