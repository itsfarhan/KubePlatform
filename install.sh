#!/bin/bash
# install.sh
#
# Installs the full Conference Application (app services + infrastructure)
# into the current Kubernetes cluster using the local Helm chart.
#
# This installs everything in one shot:
#   - Frontend, Agenda, C4P, Notifications services
#   - Kafka (via templates/kafka.yaml)
#   - Redis and PostgreSQL (via Helm chart dependencies)
#   - NGINX Ingress rule → app accessible at http://localhost
#
# Usage:
#   ./install.sh
#
# Prerequisites (run in this order):
#   1. kind create cluster --name dev --config kind-config.yaml
#   2. kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
#   3. ./kind-load.sh          (optional but saves time on slow connections)
#   4. ./install.sh            ← you are here
#
# To uninstall:
#   helm uninstall conference
#   kubectl delete pvc --all
#
# Note: If you want to manage infrastructure (Redis, PostgreSQL, Kafka) separately,
# use install-infra.sh instead and set install.infrastructure=false in values.yaml.

set -e

cd "$(dirname "$0")"

echo "==> Updating Helm chart dependencies (Redis, PostgreSQL)..."
helm dependency update helm/conference-app/

echo "==> Installing Conference Application..."
helm install conference helm/conference-app/

echo ""
echo "✅ Installation triggered. Monitor pod startup with:"
echo "   kubectl get pods -w"
echo ""
echo "Once all pods are Running, open: http://localhost"
