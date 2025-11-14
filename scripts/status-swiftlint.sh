#!/bin/bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUTPUT="$(pnpm run lint:swift 2>&1)"
STATUS=$?

if [ $STATUS -eq 0 ]; then
  echo "SwiftLint: no issues"
else
  echo "SwiftLint: failed (exit $STATUS)"
  echo "$OUTPUT" | head -n 5
fi

exit 0
