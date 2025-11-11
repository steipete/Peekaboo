#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
LOG_PATH="/tmp/commander-binder.log"
{
  echo "===== CommanderBinderTests $(date -u '+%Y-%m-%d %H:%M:%SZ') ====="
  ./runner swift test --package-path Apps/CLI --filter CommanderBinderTests
} 2>&1 | tee >(cat >> "${LOG_PATH}")
