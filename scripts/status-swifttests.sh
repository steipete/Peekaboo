#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$(mktemp)"
START_SECONDS=$(date +%s)

cd "$ROOT_DIR"

set +e
./runner swift test --package-path Apps/CLI --filter DialogCommandTests 2>&1 | tee "$LOG_FILE"
COMMAND_STATUS=${PIPESTATUS[0]}
set -e

END_SECONDS=$(date +%s)
DURATION=$((END_SECONDS - START_SECONDS))

python3 - <<'PY' "$LOG_FILE" "$COMMAND_STATUS" "$DURATION"
import json
import sys
from pathlib import Path

log_path = Path(sys.argv[1])
status_code = int(sys.argv[2])
duration = int(sys.argv[3])
status = "success" if status_code == 0 else "failure"
lines = []
if log_path.exists():
    with log_path.open('r', encoding='utf-8', errors='ignore') as handle:
        lines = [line.rstrip() for line in handle if line.strip()]
lines = lines[-5:]
summary = f"Swift tests: {status} [{duration}s]"
print(
    "POLTERGEIST_POSTBUILD_RESULT:" +
    json.dumps({
        "status": status,
        "summary": summary,
        "lines": lines,
    }, ensure_ascii=False)
)
PY

rm -f "$LOG_FILE"
exit "$COMMAND_STATUS"
