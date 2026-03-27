#!/bin/bash
# install-infra.sh
#
# Installs ONLY the infrastructure components (Redis, PostgreSQL, Kafka)
# without installing the application services.
#
# Use this when you want to:
#   - Manage infrastructure separately from application services
#   - Bring your own databases/message broker in a later chapter (e.g., Chapter 5 with Crossplane)
#   - Reinstall just the infra without touching the app
#
# After running this, deploy the app services with install.infrastructure=false:
#   helm install conference helm/conference-app/ --set install.infrastructure=false
#
# Usage:
#   ./install-infra.sh
#
# Prerequisites:
#   - Helm bitnami repo added:
#       helm repo add bitnami https://charts.bitnami.com/bitnami
#       helm repo update
#   - A running Kubernetes cluster (e.g., KinD via kind-config.yaml)

set -e

echo "==> Installing Redis..."
helm upgrade --install conference-redis bitnami/redis \
  --set architecture=standalone \
  --set image.tag=latest \
  --set master.persistence.size=1Gi \
  --wait --timeout 120s

echo "==> Creating c4p-init-sql ConfigMap (PostgreSQL schema)..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: c4p-init-sql
  namespace: default
data:
  init.sql: |
    CREATE TABLE proposals(
      id VARCHAR PRIMARY KEY NOT NULL,
      title VARCHAR NOT NULL,
      description TEXT NOT NULL,
      author VARCHAR NOT NULL,
      email VARCHAR NOT NULL,
      approved boolean,
      status VARCHAR NOT NULL
    );
EOF

echo "==> Installing PostgreSQL..."
helm upgrade --install conference-postgresql bitnami/postgresql \
  --set global.postgresql.auth.postgresPassword=postgres \
  --set primary.persistence.size=1Gi \
  --set primary.initdb.user=postgres \
  --set primary.initdb.password=postgres \
  --set primary.initdb.scriptsConfigMap=c4p-init-sql \
  --wait --timeout 220s

echo "==> Installing Kafka (standalone manifest)..."
kubectl apply -f kafka.yaml
kubectl wait --for=condition=ready pod -l app=kafka --timeout=180s

echo ""
echo "✅ Infrastructure ready!"
echo ""
echo "Next: install the app services with infrastructure disabled:"
echo "  helm install conference helm/conference-app/ --set install.infrastructure=false"
