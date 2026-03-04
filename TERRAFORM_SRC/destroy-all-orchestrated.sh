#!/usr/bin/env bash

set -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_ROOT="${SCRIPT_DIR}/.logs"
RUN_LOG_DIR="${LOG_ROOT}/destroy-all-$(date +%Y%m%d-%H%M%S)"

mkdir -p "${RUN_LOG_DIR}"

declare -A PIDS=()
declare -A LOGS=()
FAILED=()

run_tf_destroy() {
  local label="$1"
  local dir="$2"

  if [[ ! -d "${dir}" ]]; then
    echo "[${label}] ERROR: directory not found: ${dir}"
    return 1
  fi

  echo "[${label}] terraform init..."
  terraform -chdir="${dir}" init -input=false

  echo "[${label}] terraform destroy..."
  if [[ -f "${dir}/terraform.tfvars" ]]; then
    terraform -chdir="${dir}" destroy -input=false -auto-approve -var-file=terraform.tfvars
  else
    terraform -chdir="${dir}" destroy -input=false -auto-approve
  fi

  echo "[${label}] completed successfully."
}

run_and_log_background() {
  local label="$1"
  shift
  local log_file="${RUN_LOG_DIR}/${label}.log"

  LOGS["${label}"]="${log_file}"
  (
    "$@"
  ) >"${log_file}" 2>&1 &

  PIDS["${label}"]=$!
  echo "[${label}] started (pid: ${PIDS[${label}]})"
}

wait_group_or_fail() {
  local labels=("$@")
  local has_failures=0

  for label in "${labels[@]}"; do
    local pid="${PIDS[${label}]}"
    if wait "${pid}"; then
      echo "[${label}] SUCCESS (log: ${LOGS[${label}]})"
    else
      echo "[${label}] FAILED (log: ${LOGS[${label}]})"
      FAILED+=("${label}")
      has_failures=1
    fi
  done

  if [[ "${has_failures}" -ne 0 ]]; then
    echo
    echo "Destroy failed for: ${FAILED[*]}"
    echo
    for label in "${FAILED[@]}"; do
      echo "----- ${label} (last 40 lines) -----"
      tail -n 40 "${LOGS[${label}]}" || true
      echo
    done
    exit 1
  fi
}

echo "Destroy orchestration started."
echo "Logs directory: ${RUN_LOG_DIR}"
echo
echo "Phase 1: Destroy in parallel -> karpenter, microservices, shared_infra, cicd"

run_and_log_background "karpenter" run_tf_destroy "karpenter" "${SCRIPT_DIR}/06_Karpenter"
run_and_log_background "shared_infra" run_tf_destroy "shared_infra" "${SCRIPT_DIR}/04_Shared_Resources"
run_and_log_background "microservices" "${SCRIPT_DIR}/05_MicroServices/destroy-all-parallel.sh"
run_and_log_background "cicd" run_tf_destroy "cicd" "${SCRIPT_DIR}/08_CICD"

wait_group_or_fail "karpenter" "shared_infra" "microservices" "cicd"

echo
echo "Phase 1b: Destroy Addons (after karpenter)"
run_tf_destroy "addons" "${SCRIPT_DIR}/03_EKS_Addons" >"${RUN_LOG_DIR}/addons.log" 2>&1 || {
  echo "[addons] FAILED (log: ${RUN_LOG_DIR}/addons.log)"
  tail -n 40 "${RUN_LOG_DIR}/addons.log" || true
  exit 1
}
echo "[addons] SUCCESS (log: ${RUN_LOG_DIR}/addons.log)"

echo
echo "Phase 2: Destroy EKS"
run_tf_destroy "eks" "${SCRIPT_DIR}/02_EKS" >"${RUN_LOG_DIR}/eks.log" 2>&1 || {
  echo "[eks] FAILED (log: ${RUN_LOG_DIR}/eks.log)"
  tail -n 40 "${RUN_LOG_DIR}/eks.log" || true
  exit 1
}
echo "[eks] SUCCESS (log: ${RUN_LOG_DIR}/eks.log)"

echo
echo "Phase 3: Destroy VPC"
run_tf_destroy "vpc" "${SCRIPT_DIR}/01_VPC" >"${RUN_LOG_DIR}/vpc.log" 2>&1 || {
  echo "[vpc] FAILED (log: ${RUN_LOG_DIR}/vpc.log)"
  tail -n 40 "${RUN_LOG_DIR}/vpc.log" || true
  exit 1
}
echo "[vpc] SUCCESS (log: ${RUN_LOG_DIR}/vpc.log)"

echo
echo "Destroy orchestration completed successfully."
