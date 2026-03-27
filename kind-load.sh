#!/bin/bash
# kind-load.sh
#
# Pre-loads all required container images into the KinD cluster nodes.
#
# Why: KinD nodes don't share your local Docker image cache. Without this,
# Kubernetes pulls each image from the internet when a pod starts — which
# can take 10+ minutes for heavy images like Kafka (335MB) and PostgreSQL (88MB).
# Pre-loading means the app starts in ~1 minute instead.
#
# Usage:
#   ./kind-load.sh
#
# Prerequisites:
#   - KinD cluster named "dev" must already be running:
#       kind create cluster --name dev --config kind-config.yaml
#   - Docker running locally with internet access
#
# Note: Skip this if you're on a cloud provider with fast registry access.

set -e

echo "==> Pulling images from registries..."

# Infrastructure images
docker pull docker.io/bitnami/redis:7.0.11-debian-11-r12
docker pull docker.io/bitnami/postgresql:15.3.0-debian-11-r7
docker pull docker.io/bitnami/kafka:3.4.1-debian-11-r0

# Ingress controller images
docker pull registry.k8s.io/ingress-nginx/controller:v1.8.1
docker pull registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20230407

# Conference application service images
docker pull salaboy/frontend-go-1739aa83b5e69d4ccb8a5615830ae66c:v1.0.0
docker pull salaboy/agenda-service-0967b907d9920c99918e2b91b91937b3:v1.0.0
docker pull salaboy/c4p-service-a3dc0474cbfa348afcdf47a8eee70ba9:v1.0.0
docker pull salaboy/notifications-service-0e27884e01429ab7e350cb5dff61b525:v1.0.0

echo ""
echo "==> Loading images into KinD cluster 'dev'..."

# Infrastructure
kind load docker-image -n dev docker.io/bitnami/redis:7.0.11-debian-11-r12
kind load docker-image -n dev docker.io/bitnami/postgresql:15.3.0-debian-11-r7
kind load docker-image -n dev docker.io/bitnami/kafka:3.4.1-debian-11-r0

# Ingress controller
kind load docker-image -n dev registry.k8s.io/ingress-nginx/controller:v1.8.1
kind load docker-image -n dev registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20230407

# Application services
kind load docker-image -n dev salaboy/frontend-go-1739aa83b5e69d4ccb8a5615830ae66c:v1.0.0
kind load docker-image -n dev salaboy/agenda-service-0967b907d9920c99918e2b91b91937b3:v1.0.0
kind load docker-image -n dev salaboy/c4p-service-a3dc0474cbfa348afcdf47a8eee70ba9:v1.0.0
kind load docker-image -n dev salaboy/notifications-service-0e27884e01429ab7e350cb5dff61b525:v1.0.0

echo ""
echo "✅ All images loaded into KinD cluster 'dev'"
echo "   You can now run ./install.sh"
