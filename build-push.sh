#!/bin/bash
set -e

REGISTRY="ghcr.io/itsfarhan"
TAG="v1.0.0"
SRC="../platforms-on-k8s/conference-application"

echo "Logging into GHCR..."
echo $GITHUB_TOKEN | docker login ghcr.io -u itsfarhan --password-stdin

services=("agenda-service" "c4p-service" "notifications-service" "frontend-go")

for svc in "${services[@]}"; do
  echo "Building $svc..."
  docker build -t $REGISTRY/$svc:$TAG -f Dockerfile.$svc $SRC/$svc
  echo "Pushing $svc..."
  docker push $REGISTRY/$svc:$TAG
done

echo "All images pushed to $REGISTRY"
