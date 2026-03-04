#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 || $# -gt 3 ]]; then
  echo "Usage: $0 <service> [environment] [namespace]"
  echo "Example: $0 catalog dev default"
  exit 1
fi

SERVICE="$1"
ENVIRONMENT="${2:-dev}"
NAMESPACE="${3:-default}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="${SCRIPT_DIR}/releases/${SERVICE}"
CHART_DIR="${SCRIPT_DIR}/charts/microservice-base"
COMMON_VALUES="${RELEASE_DIR}/values-common.yaml"
ENV_VALUES="${RELEASE_DIR}/values-${ENVIRONMENT}.yaml"

if [[ ! -d "${RELEASE_DIR}" ]]; then
  echo "Release directory not found: ${RELEASE_DIR}"
  exit 1
fi

if [[ ! -f "${COMMON_VALUES}" ]]; then
  echo "Missing values file: ${COMMON_VALUES}"
  exit 1
fi

if [[ ! -f "${ENV_VALUES}" ]]; then
  echo "Missing values file: ${ENV_VALUES}"
  exit 1
fi

echo "Deploying service: ${SERVICE}"
echo "Environment: ${ENVIRONMENT}"
echo "Namespace: ${NAMESPACE}"
echo

helm upgrade --install "${SERVICE}" "${CHART_DIR}" \
  -f "${COMMON_VALUES}" \
  -f "${ENV_VALUES}" \
  --namespace "${NAMESPACE}" \
  --create-namespace

kubectl rollout status "deployment/${SERVICE}" -n "${NAMESPACE}" --timeout=300s

echo
echo "Service ${SERVICE} deployed successfully."
