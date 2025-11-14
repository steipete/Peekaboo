#!/bin/bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

RAW_OUTPUT="$(swiftlint lint --reporter json --quiet)"
SWIFTLINT_STATUS=$?

SUMMARY=$(
printf '%s' "$RAW_OUTPUT" | python3 <<'PY'
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    data = []
else:
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        raise SystemExit(1)
errors = sum(1 for item in data if item.get('severity', '').lower() == 'error')
warnings = sum(1 for item in data if item.get('severity', '').lower() == 'warning')
lines = [f"{errors} errors / {warnings} warnings"]
for violation in data[:5]:
    file = violation.get('file', '?').split('/')[-1]
    line = violation.get('line', '?')
    severity = violation.get('severity', '').capitalize()
    reason = violation.get('reason', '')
    lines.append(f"{file}:{line} {severity}: {reason}")
print('\\n'.join(lines))
PY
)

if [ $? -eq 0 ]; then
  echo "$SUMMARY"
  exit 0
fi

echo "failed (exit $SWIFTLINT_STATUS)"
echo "$RAW_OUTPUT" | head -n 5
exit 0
