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

# Auto-append --config if the caller didn't provide one so the CLI reads
# Peekaboo's poltergeist.config.json even though we execute from the Poltergeist repo.
NEEDS_CONFIG=true
for arg in "$@"; do
  if [[ "$arg" == "--config" || "$arg" == "-c" ]]; then
    NEEDS_CONFIG=false
    break
  fi
done

if [[ "$NEEDS_CONFIG" == "true" ]]; then
  set -- "$@" --config "$PROJECT_DIR/poltergeist.config.json"
fi

# Always run against the Peekaboo config (not the Poltergeist repo itself)
CONFIG_PATH="$PROJECT_DIR/poltergeist.config.json"
ADD_CONFIG_FLAG=true
for arg in "$@"; do
  case "$arg" in
    -c|--config) ADD_CONFIG_FLAG=false ;;
    --config=*) ADD_CONFIG_FLAG=false ;;
  esac
done
if $ADD_CONFIG_FLAG; then
  set -- "$@" --config "$CONFIG_PATH"
fi

# Run directly from TypeScript sources using tsx in the Poltergeist repo.
if { [ "$1" = "panel" ] || { [ "$1" = "status" ] && [ "$2" = "panel" ]; }; }; then
  exec pnpm --dir "$POLTER_DIR" exec tsx --watch "$CLI_TS" "$@"
else
  if [ -f "$CLI_JS" ]; then
    exec pnpm --dir "$POLTER_DIR" exec node "$CLI_JS" "$@"
  else
    exec pnpm --dir "$POLTER_DIR" exec tsx "$CLI_TS" "$@"
  fi
fi
