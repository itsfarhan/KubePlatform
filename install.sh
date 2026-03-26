#!/bin/bash
set -e

cd "$(dirname "$0")"

helm dependency update helm/conference-app/
helm install conference helm/conference-app/
