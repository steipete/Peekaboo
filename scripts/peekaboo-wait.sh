#!/bin/bash
# Smart CLI Wrapper for Peekaboo - Powered by pgrun
PGRUN_PATH="/Users/steipete/Projects/poltergeist/dist/pgrun.js"
[ ! -f "$PGRUN_PATH" ] && echo "❌ pgrun not found at: $PGRUN_PATH" >&2 && exit 1
exec node "$PGRUN_PATH" peekaboo ${PEEKABOO_WAIT_DEBUG:+--verbose} "$@"