#!/bin/bash
# Simple runner for axorc, taking a JSON file as input.
# AXORC_PATH should be the path to your axorc executable.
# If not set, it defaults to a path relative to this script.

# Determine the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Set AXORC_PATH relative to the script's directory if not already set
: ${AXORC_PATH:="$SCRIPT_DIR/AXorcist/.build/debug/axorc"}

# Check if AXORC_PATH exists and is executable
if [ ! -x "$AXORC_PATH" ]; then
    echo "Error: axorc executable not found or not executable at $AXORC_PATH"
    echo "Please set AXORC_PATH environment variable or ensure it's built at the default location."
    exit 1
fi

DEBUG_FLAG=""
POSITIONAL_ARGS=()

# Parse arguments for --debug and file/json payload
while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug)
            DEBUG_FLAG="--debug"
            shift # past argument
            ;;
        --file)
            if [[ -z "$2" || ! -f "$2" ]]; then
                echo "Error: File not provided or not found after --file argument."
                exit 1
            fi
            INPUT_JSON=$(cat "$2")
            USE_STDIN_FLAG=true
            shift # past argument
            shift # past value
            ;;
        --json)
            if [[ -z "$2" ]]; then
                echo "Error: JSON string not provided after --json argument."
                exit 1
            fi
            INPUT_JSON="$2"
            USE_STDIN_FLAG=true
            shift # past argument
            shift # past value
            ;;
        *)
            POSITIONAL_ARGS+=("$1") # unknown option will be captured if axorc supports more
            shift # past argument
            ;;
    esac
done

if [ -z "$INPUT_JSON" ]; then
    echo "Error: No JSON input provided via --file or --json."
    echo "Usage: $0 [--debug] --file /path/to/command.json OR $0 [--debug] --json '{"command":"ping"}'"
    exit 1
fi

echo "--- DEBUG_RUNNER: INPUT_JSON content before piping --- BEGIN"
printf "%s\n" "$INPUT_JSON"
echo "--- DEBUG_RUNNER: INPUT_JSON content before piping --- END"
echo "--- DEBUG_RUNNER: AXORC_PATH: $AXORC_PATH"
echo "--- DEBUG_RUNNER: DEBUG_FLAG: $DEBUG_FLAG"


# Execute axorc with the input JSON
if [ "$USE_STDIN_FLAG" = true ]; then
    printf '%s' "$INPUT_JSON" | "$AXORC_PATH" --stdin $DEBUG_FLAG "${POSITIONAL_ARGS[@]}"
    AXORC_EXIT_CODE=$?
    echo "--- DEBUG_RUNNER: axorc exit code: $AXORC_EXIT_CODE ---"
else
    # This case should not be reached if --file or --json is mandatory
    echo "Error: USE_STDIN_FLAG was not set, programming error in runner script."
    exit 1
fi
