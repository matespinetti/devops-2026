#!/usr/bin/env bash

set -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES=("cart" "catalog" "checkout" "orders")
LOG_ROOT="${SCRIPT_DIR}/.logs"
RUN_LOG_DIR="${LOG_ROOT}/apply-$(date +%Y%m%d-%H%M%S)"

mkdir -p "${RUN_LOG_DIR}"

declare -A PIDS=()
declare -A LOGS=()
FAILED_SERVICES=()

run_service_apply() {
  local service="$1"
  local service_dir="${SCRIPT_DIR}/${service}"

  if [[ ! -d "${service_dir}" ]]; then
    echo "[${service}] ERROR: directory not found: ${service_dir}"
    return 1
  fi

  echo "[${service}] terraform init..."
  terraform -chdir="${service_dir}" init -input=false

  echo "[${service}] terraform apply..."
  if [[ -f "${service_dir}/terraform.tfvars" ]]; then
    terraform -chdir="${service_dir}" apply -input=false -auto-approve -var-file=terraform.tfvars
  else
    terraform -chdir="${service_dir}" apply -input=false -auto-approve
  fi

  echo "[${service}] completed successfully."
}

echo "Starting parallel Terraform apply for microservices..."
echo "Services: ${SERVICES[*]}"
echo "Logs: ${RUN_LOG_DIR}"
echo

for service in "${SERVICES[@]}"; do
  log_file="${RUN_LOG_DIR}/${service}.log"
  LOGS["${service}"]="${log_file}"

  (
    run_service_apply "${service}"
  ) >"${log_file}" 2>&1 &

  PIDS["${service}"]=$!
  echo "[${service}] started (pid: ${PIDS[${service}]})"
done

echo
echo "Waiting for all services to finish..."

for service in "${SERVICES[@]}"; do
  pid="${PIDS[${service}]}"
  if wait "${pid}"; then
    echo "[${service}] SUCCESS (log: ${LOGS[${service}]})"
  else
    echo "[${service}] FAILED (log: ${LOGS[${service}]})"
    FAILED_SERVICES+=("${service}")
  fi
done

echo
if [[ "${#FAILED_SERVICES[@]}" -gt 0 ]]; then
  echo "Parallel apply finished with failures in: ${FAILED_SERVICES[*]}"
  echo
  for service in "${FAILED_SERVICES[@]}"; do
    echo "----- ${service} (last 40 log lines) -----"
    tail -n 40 "${LOGS[${service}]}" || true
    echo
  done
  exit 1
fi

echo "Parallel apply completed successfully for all services."
echo "Detailed logs are in: ${RUN_LOG_DIR}"
