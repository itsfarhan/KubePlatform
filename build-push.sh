#!/bin/bash
# build-push.sh
#
# Builds all 4 Conference Application service images and pushes them
# to your container registry (default: ghcr.io).
#
# Usage:
#   ./build-push.sh                          # uses default REGISTRY below
#   REGISTRY=docker.io/youruser ./build-push.sh
#   REGISTRY=ghcr.io/youruser TAG=v1.1.0 ./build-push.sh
#
# Prerequisites:
#   - Docker running locally
#   - Logged in to your registry: docker login ghcr.io -u <username>
#   - GITHUB_TOKEN env var set (if pushing to GHCR)
#   - Source code at ../platforms-on-k8s/conference-application/
#
# After running this, update helm/conference-app/values.yaml:
#   services.registry: <your-registry>
#   services.tag: <your-tag>

set -e

REGISTRY="${REGISTRY:-ghcr.io/itsfarhan}"
TAG="${TAG:-v1.0.0}"
SRC="../platforms-on-k8s/conference-application"

echo "==> Registry : $REGISTRY"
echo "==> Tag      : $TAG"
echo "==> Source   : $SRC"
echo ""

if [ -n "$GITHUB_TOKEN" ]; then
  echo "==> Logging into GHCR..."
  echo "$GITHUB_TOKEN" | docker login ghcr.io -u "${REGISTRY#ghcr.io/}" --password-stdin
fi

services=("agenda-service" "c4p-service" "notifications-service" "frontend-go")

for svc in "${services[@]}"; do
  echo "==> Building $svc..."
  docker build -t "$REGISTRY/$svc:$TAG" -f "Dockerfile.$svc" "$SRC/$svc"
  echo "==> Pushing $svc..."
  docker push "$REGISTRY/$svc:$TAG"
  echo ""
done

echo "✅ All images pushed to $REGISTRY"
echo ""
echo "Next: update helm/conference-app/values.yaml with:"
echo "  services.registry: $REGISTRY"
echo "  services.tag: $TAG"
