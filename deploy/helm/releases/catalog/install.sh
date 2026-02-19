#!/usr/bin/env bash
set -euo pipefail

helm upgrade --install catalog ../../charts/microservice-base \
  -f values-common.yaml \
  -f values-dev.yaml \
  --namespace default \
  --create-namespace

kubectl rollout status deployment/catalog --timeout=180s
