#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${MENU_DIALOG_SOAK_LOG_DIR:-/tmp/menu-dialog-soak}"
BUILD_PATH="${MENU_DIALOG_SOAK_BUILD_PATH:-/tmp/menu-dialog-soak.build}"
EXIT_PATH="${MENU_DIALOG_SOAK_EXIT_PATH:-$LOG_DIR/last-exit.code}"
ITERATIONS="${MENU_DIALOG_SOAK_ITERATIONS:-1}"
TEST_FILTER="${MENU_DIALOG_SOAK_FILTER:-MenuDialogLocalHarnessTests/menuStressLoop}"

mkdir -p "$LOG_DIR"

write_exit_code() {
  local status=${1:-$?}
  mkdir -p "$(dirname "$EXIT_PATH")"
  printf "%s" "$status" > "$EXIT_PATH"
}
trap 'write_exit_code $?' EXIT

run_iteration() {
  local iteration="$1"
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local log_path="$LOG_DIR/iteration-${iteration}.log"
  echo "[${timestamp}] Starting soak iteration ${iteration}/${ITERATIONS}" | tee "$log_path"

  (
    cd "$ROOT_DIR"
    RUN_LOCAL_TESTS="${RUN_LOCAL_TESTS:-true}" swift test \
      --package-path Apps/CLI \
      --build-path "$BUILD_PATH" \
      --filter "$TEST_FILTER"
  ) 2>&1 | tee -a "$log_path"

  local status=${PIPESTATUS[0]}
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  if [[ "$status" -eq 0 ]]; then
    echo "[${timestamp}] Iteration ${iteration} completed successfully" | tee -a "$log_path"
  else
    echo "[${timestamp}] Iteration ${iteration} failed with status ${status}" | tee -a "$log_path"
  fi
  return "$status"
}

for ((i = 1; i <= ITERATIONS; i++)); do
  if ! run_iteration "$i"; then
    exit 1
  fi

  # Surface progress at least once per minute even if more runs remain.
  if [[ "$i" -lt "$ITERATIONS" ]]; then
    echo "[info] Completed iteration ${i}; sleeping 5s before next soak pass."
    sleep 5
  fi
done
