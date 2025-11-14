#!/bin/bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TMP_JSON="$(mktemp)"
swiftlint lint --reporter json --quiet > "$TMP_JSON"
SWIFTLINT_STATUS=$?

SUMMARY=$(SWIFTLINT_JSON="$TMP_JSON" python3 <<'PY'
import json, os
path = os.environ.get('SWIFTLINT_JSON')
if not path or not os.path.exists(path):
    data = []
else:
    with open(path, 'r', encoding='utf-8') as f:
        raw = f.read().strip()
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
print('\n'.join(lines))
PY
)

if [ $? -eq 0 ]; then
  echo "$SUMMARY"
  rm -f "$TMP_JSON"
  exit 0
fi

echo "failed (exit $SWIFTLINT_STATUS)"
head -n 5 "$TMP_JSON"
rm -f "$TMP_JSON"
exit 0
