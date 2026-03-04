#!/usr/bin/env bash

set -euo pipefail

ENVIRONMENT="${1:-dev}"
NAMESPACE="${2:-default}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SERVICES=("cart" "catalog" "checkout" "orders" "ui")

echo "Deploying all services"
echo "Environment: ${ENVIRONMENT}"
echo "Namespace: ${NAMESPACE}"
echo "Services: ${SERVICES[*]}"
echo

for service in "${SERVICES[@]}"; do
  echo "==============================="
  echo "Deploying ${service}"
  echo "==============================="
  "${SCRIPT_DIR}/deploy-service.sh" "${service}" "${ENVIRONMENT}" "${NAMESPACE}"
  echo
done

echo "All services deployed successfully."
