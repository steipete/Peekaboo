#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_PATH=${CLI_BUILD_LOG:-/tmp/cli-build.log}
EXIT_PATH=${CLI_BUILD_EXIT:-/tmp/cli-build.exit}
BUILD_PATH=${CLI_BUILD_DIR:-/tmp/peekaboo-cli-build}

if command -v xcbeautify >/dev/null 2>&1; then
  USE_XCBEAUTIFY=1
else
  USE_XCBEAUTIFY=0
fi

pipe_build_output() {
  if [[ "$USE_XCBEAUTIFY" -eq 1 ]]; then
    xcbeautify "$@"
  else
    cat
  fi
}

write_exit_code() {
  local status=${1:-$?}
  mkdir -p "$(dirname "$EXIT_PATH")"
  printf "%s" "$status" > "$EXIT_PATH"
}
trap 'write_exit_code $?' EXIT

mkdir -p "$(dirname "$LOG_PATH")"
rm -f "$LOG_PATH" "$EXIT_PATH"

cd "$ROOT_DIR"

set +e
swift build --package-path Apps/CLI --build-path "$BUILD_PATH" "$@" 2>&1 | pipe_build_output | tee "$LOG_PATH"
BUILD_STATUS=${PIPESTATUS[0]}
set -e

exit "$BUILD_STATUS"
