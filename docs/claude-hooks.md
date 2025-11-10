---
summary: 'Claude Code pre-command hooks for git safety'
read_when:
  - Setting up git protection for AI agents
  - Debugging blocked git commands
  - Understanding hook behavior
---

# Claude Code Git Protection Hooks

This document describes the pre-command hooks that prevent AI agents (Claude Code, etc.) from executing destructive git commands.

## Overview

Claude Code supports `PreToolUse` hooks that intercept tool calls before execution. We use this to enforce git safety policies, preventing agents from accidentally destroying work with commands like `git reset --hard`.

## Architecture

**Two-layer protection:**

1. **Universal block**: `git reset --hard` is ALWAYS blocked for AI agents, regardless of project
2. **Project-specific**: If `./runner` exists, ALL git commands must go through it

## Installation

The hook is already installed in this project. For reference or to reinstall:

```bash
# Create hook directory
mkdir -p .claude/hooks

# Create the pre-command hook
cat > .claude/hooks/pre_bash.py << 'EOF'
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
EOF

chmod +x .claude/hooks/pre_bash.py

# Configure Claude Code to use the hook
cat > .claude/settings.local.json << 'EOF'
{
  "enableAllProjectMcpServers": false,
  "hooks": {
    "PreToolUse": [
      {
        "tool": "Bash",
        "command": ["python3", ".claude/hooks/pre_bash.py"]
      }
    ]
  }
}
EOF
```

**Activation**: Restart Claude Code after installation.

## What Gets Blocked

### Always Blocked (Universal)
- `git reset --hard` - Destroys uncommitted work

### Blocked in Projects with ./runner
- `git status` → must use `./runner git status`
- `git diff` → must use `./runner git diff`
- `git add` → must use `./scripts/committer`
- `git commit` → must use `./scripts/committer`
- `git reset` → must use `./runner git reset` (with consent)
- `git checkout` → must use `./runner git checkout` (with consent)
- Any other git command → must use `./runner git <subcommand>`

## How It Works

1. **Hook triggers**: When an AI agent tries to use the Bash tool
2. **Hook reads**: Command from stdin as JSON
3. **Hook checks**: Patterns against blocked list
4. **Hook blocks**: Exit code 2 prevents execution
5. **Hook allows**: Exit code 0 lets command through

The hook runs BEFORE the command executes, so blocked commands never reach the shell.

## Runner Integration

When `./runner` exists, the hook delegates all git policy enforcement to it. The runner (via `scripts/git-policy.ts`) enforces:

- **Destructive commands**: `reset`, `checkout`, `clean`, `restore`, `switch`, `stash`, `branch`, `filter-branch`, `fast-import` - require `RUNNER_THE_USER_GAVE_ME_CONSENT=1`
- **Guarded commands**: `push`, `pull`, `merge`, `rebase`, `cherry-pick` - require explicit consent
- **Commit workflow**: `add`, `commit` - must use `./scripts/committer` for selective staging

See `scripts/git-policy.ts` lines 28-38 for the complete policy definitions.

## Testing

```bash
# This should be blocked:
git reset --hard HEAD

# Expected output:
# BLOCKED: git reset --hard is NEVER allowed for AI agents
# Attempted: git reset --hard HEAD
# Only the user can run this command directly.

# This should work (in projects with runner):
./runner git status

# This should be blocked (in projects with runner):
git status

# Expected output:
# BLOCKED: All git commands must use ./runner in this project
# Use: ./runner git <subcommand>
```

## Troubleshooting

### Hook doesn't trigger
- Restart Claude Code
- Check `.claude/settings.local.json` has the hooks configuration
- Verify `.claude/hooks/pre_bash.py` is executable: `ls -la .claude/hooks/`

### False positives
- Commands containing "git" in arguments (not as a command) might trigger
- Adjust the regex in `pre_bash.py` if needed

### Hook errors
- The hook fails open (exits 0 on errors) to avoid breaking workflows
- Check Python 3 is available: `which python3`

## Files

- `.claude/hooks/pre_bash.py` - The actual hook script
- `.claude/settings.local.json` - Claude Code configuration
- `scripts/git-policy.ts` - Runner's git policy enforcement
- `scripts/runner.ts` - Command execution wrapper

## References

- [Claude Code Hooks Documentation](https://docs.claude.com/claude-code/hooks)
- Blog post: [Preventing git commit --amend with Claude Code Hooks](https://kreako.fr/blog/20250920-claude-code-commit-amend/)
- Git hooks: `scripts/git-policy.ts` (lines 28-159)
