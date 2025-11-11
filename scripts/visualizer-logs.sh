#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/visualizer-logs.sh [--stream] [--last <duration>] [--predicate <predicate>]

Options:
  --stream               Stream logs live (uses `log stream`). Default shows history via `log show`.
  --last <duration>      Duration passed to `log show --last` (default: 10m). Ignored with --stream.
  --predicate <expr>     Override the default unified logging predicate.
  -h, --help             Display this help message.

The default predicate captures all VisualizationClient/VisualizerEventReceiver traffic
on the `boo.peekaboo.core` and `boo.peekaboo.mac` subsystems.
USAGE
}

MODE="show"
LAST="10m"
PREDICATE='(subsystem == "boo.peekaboo.core" && category CONTAINS "Visualization") || (subsystem == "boo.peekaboo.mac" && category CONTAINS "Visualizer")'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stream)
      MODE="stream"
      shift
      ;;
    --last)
      [[ $# -ge 2 ]] || { echo "--last requires a duration" >&2; exit 1; }
      LAST="$2"
      shift 2
      ;;
    --predicate)
      [[ $# -ge 2 ]] || { echo "--predicate requires an expression" >&2; exit 1; }
      PREDICATE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "$MODE" == "stream" ]]; then
  log stream --style compact --predicate "$PREDICATE"
else
  log show --style compact --last "$LAST" --predicate "$PREDICATE"
fi
