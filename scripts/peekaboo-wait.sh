#!/bin/bash
# Smart CLI Wrapper for Peekaboo - Powered by polter
exec polter peekaboo ${PEEKABOO_WAIT_DEBUG:+--verbose} "$@"