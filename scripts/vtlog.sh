#!/bin/bash

# Default values
LINES=50
TIME="5m"
LEVEL="info"
CATEGORY=""
SEARCH=""
OUTPUT=""
DEBUG=false
FOLLOW=false
ERRORS_ONLY=false
NO_TAIL=false
JSON=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--lines)
            LINES="$2"
            shift 2
            ;;
        -l|--last)
            TIME="$2"
            shift 2
            ;;
        -c|--category)
            CATEGORY="$2"
            shift 2
            ;;
        -s|--search)
            SEARCH="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT="$2"
            shift 2
            ;;
        -d|--debug)
            DEBUG=true
            LEVEL="debug"
            shift
            ;;
        -f|--follow)
            FOLLOW=true
            shift
            ;;
        -e|--errors)
            ERRORS_ONLY=true
            LEVEL="error"
            shift
            ;;
        --all)
            NO_TAIL=true
            shift
            ;;
        --json)
            JSON=true
            shift
            ;;
        -h|--help)
            echo "Usage: vtlog.sh [options]"
            echo ""
            echo "Options:"
            echo "  -n, --lines NUM      Number of lines to show (default: 50)"
            echo "  -l, --last TIME      Time range to search (default: 5m)"
            echo "  -c, --category CAT   Filter by category"
            echo "  -s, --search TEXT    Search for specific text"
            echo "  -o, --output FILE    Output to file"
            echo "  -d, --debug          Show debug level logs"
            echo "  -f, --follow         Stream logs continuously"
            echo "  -e, --errors         Show only errors"
            echo "  --all                Show all logs without tail limit"
            echo "  --json               Output in JSON format"
            echo "  -h, --help           Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Build predicate - using PeekabooInspector's subsystem
PREDICATE="subsystem == \"com.steipete.PeekabooInspector\""

if [[ -n "$CATEGORY" ]]; then
    PREDICATE="$PREDICATE AND category == \"$CATEGORY\""
fi

if [[ -n "$SEARCH" ]]; then
    PREDICATE="$PREDICATE AND eventMessage CONTAINS[c] \"$SEARCH\""
fi

# Build command
if [[ "$FOLLOW" == true ]]; then
    CMD="log stream --predicate '$PREDICATE' --level $LEVEL"
else
    # log show uses different flags for log levels
    case $LEVEL in
        debug)
            CMD="log show --predicate '$PREDICATE' --debug --last $TIME"
            ;;
        error)
            # For errors, we need to filter by eventType in the predicate
            PREDICATE="$PREDICATE AND eventType == \"error\""
            CMD="log show --predicate '$PREDICATE' --info --debug --last $TIME"
            ;;
        *)
            CMD="log show --predicate '$PREDICATE' --info --last $TIME"
            ;;
    esac
fi

if [[ "$JSON" == true ]]; then
    CMD="$CMD --style json"
fi

# Execute command
if [[ -n "$OUTPUT" ]]; then
    if [[ "$NO_TAIL" == true ]]; then
        eval $CMD > "$OUTPUT"
    else
        eval $CMD | tail -n $LINES > "$OUTPUT"
    fi
else
    if [[ "$NO_TAIL" == true ]]; then
        eval $CMD
    else
        eval $CMD | tail -n $LINES
    fi
fi