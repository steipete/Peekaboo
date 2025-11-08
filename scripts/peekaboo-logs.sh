#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/peekaboo-logs.sh [options] [-- additional log(1) args]

Fetch unified logging output for Peekaboo subsystems with sensible defaults.
If no options are supplied it shows the last 5 minutes from the core, mac, and visualizer subsystems.

Options:
  --last <duration>      Duration for `log show --last` (default: 5m)
  --since <timestamp>    Start timestamp for `log show --start`
  --stream               Use `log stream` instead of `log show`
  --subsystem <name>     Add another subsystem to the predicate (repeatable)
  --predicate <expr>     Override the predicate entirely
  --style <style>        Set `log` style (default: compact)
  -h, --help             Show this message
USAGE
}

last_duration="5m"
start_time=""
use_stream=false
style="compact"
custom_predicate=""
subsystems=("boo.peekaboo.core" "boo.peekaboo.mac" "boo.peekaboo.visualizer")
extra_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --last)
      last_duration="$2"
      shift 2
      ;;
    --since)
      start_time="$2"
      shift 2
      ;;
    --stream)
      use_stream=true
      shift
      ;;
    --subsystem)
      subsystems+=("$2")
      shift 2
      ;;
    --predicate)
      custom_predicate="$2"
      shift 2
      ;;
    --style)
      style="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      extra_args+=("$@")
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      extra_args+=("$1")
      shift
      ;;
  esac
done

if [[ -n "$custom_predicate" ]]; then
  predicate="$custom_predicate"
else
  predicate_parts=()
  for subsystem in "${subsystems[@]}"; do
    predicate_parts+=("subsystem == \"${subsystem}\"")
  done
  predicate="${predicate_parts[0]}"
  for part in "${predicate_parts[@]:1}"; do
    predicate+=" OR ${part}"
  done
fi

log_cmd=(log)
if $use_stream; then
  log_cmd+=(stream)
else
  log_cmd+=(show)
  if [[ -n "$start_time" ]]; then
    log_cmd+=(--start "$start_time")
  else
    log_cmd+=(--last "$last_duration")
  fi
fi

log_cmd+=(--style "$style" --predicate "$predicate")
if ((${#extra_args[@]} > 0)); then
  log_cmd+=("${extra_args[@]}")
fi

exec "${log_cmd[@]}"
