#!/bin/bash

# Wrapper script to run Poltergeist from the correct directory
# This works around the issue where Poltergeist doesn't handle
# being run from outside its directory properly

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# Change to project directory to ensure paths are resolved correctly
cd "$PROJECT_DIR"

POLTER_DIR="$(cd "$PROJECT_DIR/../poltergeist" && pwd)"
CLI_TS="$POLTER_DIR/src/cli.ts"
POLTER_TS="$POLTER_DIR/src/polter.ts"

# Ensure Node can resolve Poltergeist dependencies even when invoked outside pnpm context
export NODE_PATH="${NODE_PATH:-$POLTER_DIR/node_modules}"

# Determine whether to route to the poltergeist CLI (daemon/status/etc)
# or the standalone polter entrypoint (used for targets like `peekaboo`).
COMMAND="${1:-}"
IS_POLTERGEIST_COMMAND=false

case "$COMMAND" in
  daemon|start|haunt|stop|rest|restart|pause|resume|status|logs|wait|panel|project|init|list|clean|version|polter|-h|--help|"")
    IS_POLTERGEIST_COMMAND=true
    ;;
esac

# Ensure peekaboo targets always run inside a PTY so downstream tools (e.g., Swiftdansi)
# see an interactive terminal even when invoked from CI or scripted shells.
if ! $IS_POLTERGEIST_COMMAND && [ "$COMMAND" = "peekaboo" ] && [ -z "$POLTERGEIST_WRAPPER_PTY" ]; then
  if command -v script >/dev/null 2>&1; then
    export POLTERGEIST_WRAPPER_PTY=1
    exec script -q /dev/null "$0" "$@"
  fi
fi

if $IS_POLTERGEIST_COMMAND; then
  # Auto-append --config so poltergeist commands read Peekaboo's config when invoked from elsewhere.
  ADD_CONFIG_FLAG=true
  for arg in "$@"; do
    case "$arg" in
      -c|--config|--config=*) ADD_CONFIG_FLAG=false ;;
    esac
  done
  if $ADD_CONFIG_FLAG; then
    set -- "$@" --config "$PROJECT_DIR/poltergeist.config.json"
  fi

  # Run poltergeist CLI (daemon/status/project/etc) straight from source so we
  # always pick up local changes without rebuilding dist artifacts.
  if { [ "$1" = "panel" ] || { [ "$1" = "status" ] && [ "$2" = "panel" ]; }; }; then
    exec pnpm --dir "$POLTER_DIR" exec tsx --watch "$CLI_TS" "$@"
  else
    exec pnpm --dir "$POLTER_DIR" exec tsx "$CLI_TS" "$@"
  fi
else
  # Route to the standalone polter entrypoint for executable targets (e.g., `peekaboo agent`).
  TSX_BIN="$POLTER_DIR/node_modules/.bin/tsx"
  if [ -x "$TSX_BIN" ]; then
    exec "$TSX_BIN" "$POLTER_TS" "$@"
  else
    exec pnpm --dir "$POLTER_DIR" exec tsx "$POLTER_TS" "$@"
  fi
fi
