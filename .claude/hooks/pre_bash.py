#!/usr/bin/env python3
import json
import sys
import re
import os

try:
    data = json.load(sys.stdin)
    cmd = data.get("tool_input", {}).get("command", "")

    # ALWAYS block git reset --hard, regardless of project
    if re.search(r'\bgit\s+reset\s+--hard\b', cmd):
        print("BLOCKED: git reset --hard is NEVER allowed for AI agents", file=sys.stderr)
        print(f"Attempted: {cmd}", file=sys.stderr)
        print("Only the user can run this command directly.", file=sys.stderr)
        sys.exit(2)

    # If ./runner exists, enforce stricter rules
    if os.path.exists('./runner'):
        if re.search(r'\bgit\s+', cmd) and './runner' not in cmd and 'runner git' not in cmd:
            print("BLOCKED: All git commands must use ./runner in this project", file=sys.stderr)
            print(f"Attempted: {cmd}", file=sys.stderr)
            print("Use: ./runner git <subcommand>", file=sys.stderr)
            sys.exit(2)

    sys.exit(0)
except:
    sys.exit(0)
