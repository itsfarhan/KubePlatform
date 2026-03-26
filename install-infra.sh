#!/bin/bash
set -e

echo "==> Installing Redis..."
helm upgrade --install conference-redis bitnami/redis \
  --set architecture=standalone \
  --set image.tag=latest \
  --set master.persistence.size=1Gi \
  --wait --timeout 120s

echo "==> Creating c4p-init-sql ConfigMap..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: c4p-init-sql
  namespace: default
data:
  init.sql: |
    CREATE TABLE proposals( id VARCHAR PRIMARY KEY NOT NULL, title VARCHAR NOT NULL, description TEXT NOT NULL, author VARCHAR NOT NULL, email VARCHAR NOT NULL, approved boolean, status VARCHAR NOT NULL);
EOF

echo "==> Installing PostgreSQL..."
helm upgrade --install conference-postgresql bitnami/postgresql \
  --set global.postgresql.auth.postgresPassword=postgres \
  --set primary.persistence.size=1Gi \
  --set primary.initdb.user=postgres \
  --set primary.initdb.password=postgres \
  --set primary.initdb.scriptsConfigMap=c4p-init-sql \
  --wait --timeout 220s

echo "==> Installing Kafka..."
kubectl apply -f kafka.yaml
kubectl wait --for=condition=ready pod -l app=kafka --timeout=180s

echo "Infrastructure ready!"
