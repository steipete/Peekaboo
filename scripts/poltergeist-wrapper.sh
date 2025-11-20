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
CLI_JS="$POLTER_DIR/dist/cli.js"
POLTER_TS="$POLTER_DIR/src/polter.ts"
POLTER_JS="$POLTER_DIR/dist/polter.js"

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

  # Run poltergeist CLI (daemon/status/project/etc).
  if { [ "$1" = "panel" ] || { [ "$1" = "status" ] && [ "$2" = "panel" ]; }; }; then
    exec pnpm --dir "$POLTER_DIR" exec tsx --watch "$CLI_TS" "$@"
  else
    if [ -f "$CLI_JS" ]; then
      exec pnpm --dir "$POLTER_DIR" exec node "$CLI_JS" "$@"
    else
      exec pnpm --dir "$POLTER_DIR" exec tsx "$CLI_TS" "$@"
    fi
  fi
else
  # Route to the standalone polter entrypoint for executable targets (e.g., `peekaboo agent`).
  if [ -f "$POLTER_JS" ]; then
    exec node "$POLTER_JS" "$@"
  else
    TSX_BIN="$POLTER_DIR/node_modules/.bin/tsx"
    if [ -x "$TSX_BIN" ]; then
      exec "$TSX_BIN" "$POLTER_TS" "$@"
    else
      exec pnpm --dir "$POLTER_DIR" exec tsx "$POLTER_TS" "$@"
    fi
  fi
fi
