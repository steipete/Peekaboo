#!/bin/bash

set -euo pipefail

NAME=""
RUNS=10
LOG_ROOT="${LOG_ROOT:-$PWD/.artifacts/playground-tools}"
BIN="${PEEKABOO_BIN:-$PWD/peekaboo}"

usage() {
  cat <<'EOF'
Usage: peekaboo-perf.sh --name <slug> [--runs N] [--log-root DIR] [--bin PATH] -- <peekaboo args...>

Runs a Peekaboo CLI command N times, captures JSON output per run, and writes a summary JSON
with mean/median/p95/min/max based on `data.execution_time` (falls back to wall time if missing).

Examples:
  ./Apps/Playground/scripts/peekaboo-perf.sh --name see-click-fixture --runs 10 -- \
    see --app boo.peekaboo.playground.debug --mode window --window-title "Click Fixture" --json-output

  ./Apps/Playground/scripts/peekaboo-perf.sh --name click-single --runs 20 -- \
    click "Single Click" --snapshot <id> --app boo.peekaboo.playground.debug --json-output
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      NAME="${2:-}"
      shift 2
      ;;
    --runs)
      RUNS="${2:-}"
      shift 2
      ;;
    --log-root)
      LOG_ROOT="${2:-}"
      shift 2
      ;;
    --bin)
      BIN="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$NAME" ]]; then
  echo "--name is required" >&2
  usage >&2
  exit 2
fi

if [[ $# -eq 0 ]]; then
  echo "Missing peekaboo args after --" >&2
  usage >&2
  exit 2
fi

if [[ ! -x "$BIN" ]]; then
  echo "Peekaboo binary not executable: $BIN" >&2
  echo "Tip: set PEEKABOO_BIN=/path/to/peekaboo or pass --bin" >&2
  exit 2
fi

mkdir -p "$LOG_ROOT"

TS="$(date +%Y%m%d-%H%M%S)"
PATTERN="$LOG_ROOT/${TS}-${NAME}-*.json"
SUMMARY="$LOG_ROOT/${TS}-${NAME}-summary.json"

echo "Running $RUNS iterations:"
echo "- bin: $BIN"
echo "- out: $LOG_ROOT"
echo "- cmd: $*"

for i in $(seq 1 "$RUNS"); do
  OUT="$LOG_ROOT/${TS}-${NAME}-${i}.json"
  START="$(python3 - <<'PY'
import time
print(time.time())
PY
)"

  set +e
  "$BIN" "$@" >"$OUT"
  EXIT_CODE="$?"
  set -e

  END="$(python3 - <<'PY'
import time
print(time.time())
PY
)"

  WALL="$(python3 - <<PY
start=float("$START")
end=float("$END")
print(end-start)
PY
)"

  if [[ "$EXIT_CODE" -ne 0 ]]; then
    echo "Run $i failed (exit=$EXIT_CODE): $OUT" >&2
  fi

  python3 - <<PY
import json
from pathlib import Path

path = Path("$OUT")
raw = path.read_text()
try:
  data = json.loads(raw)
except Exception:
  data = {"success": False, "data": {}, "raw_output": raw}
if not isinstance(data, dict):
  data = {"success": False, "data": {}, "raw_output": raw}
if "data" not in data or not isinstance(data.get("data"), dict):
  data["data"] = {}
data["data"]["wall_time"] = float("$WALL")
data["data"]["exit_code"] = int("$EXIT_CODE")
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY

  echo "- $i/$RUNS -> $OUT (wall=${WALL}s, exit=$EXIT_CODE)"
done

export PEEKABOO_PERF_COMMAND="$BIN $*"

python3 - <<PY
import glob
import json
import math
import os
from pathlib import Path

paths = [p for p in sorted(glob.glob("$PATTERN")) if not p.endswith("-summary.json")]
summary_path = Path("$SUMMARY")
command_str = os.environ.get("PEEKABOO_PERF_COMMAND", "")

def percentile(sorted_values, pct):
  if not sorted_values:
    return None
  if len(sorted_values) == 1:
    return sorted_values[0]
  k = (len(sorted_values) - 1) * pct
  f = math.floor(k)
  c = math.ceil(k)
  if f == c:
    return sorted_values[int(k)]
  d0 = sorted_values[int(f)] * (c - k)
  d1 = sorted_values[int(c)] * (k - f)
  return d0 + d1

execution_times = []
wall_times = []
failures = []

for p in paths:
  raw = Path(p).read_text()
  payload = json.loads(raw)
  data = payload.get("data", {}) or {}
  exit_code = int(data.get("exit_code", 0))
  if exit_code != 0:
    failures.append({"path": p, "exit_code": exit_code})
  exec_t = data.get("execution_time")
  if exec_t is None:
    exec_t = data.get("executionTime")
  if exec_t is None:
    exec_t = data.get("execution_time_s")
  if exec_t is None:
    exec_t = data.get("executionTimeSeconds")
  wall_t = data.get("wall_time")
  if isinstance(exec_t, (int, float)):
    execution_times.append(float(exec_t))
  if isinstance(wall_t, (int, float)):
    wall_times.append(float(wall_t))

execution_times_sorted = sorted(execution_times)
wall_times_sorted = sorted(wall_times)

def stats(values_sorted):
  if not values_sorted:
    return None
  n = len(values_sorted)
  mean = sum(values_sorted) / n
  median = percentile(values_sorted, 0.50)
  p95 = percentile(values_sorted, 0.95)
  return {
    "n": n,
    "samples_s": values_sorted,
    "mean_s": mean,
    "median_s": median,
    "p95_s": p95,
    "min_s": values_sorted[0],
    "max_s": values_sorted[-1],
  }

summary = {
  "pattern": "$PATTERN",
  "command": command_str,
  "timestamp": "$TS",
  "execution_time": stats(execution_times_sorted),
  "wall_time": stats(wall_times_sorted),
  "failures": failures,
}

summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
print(str(summary_path))
PY

echo "Summary: $SUMMARY"
