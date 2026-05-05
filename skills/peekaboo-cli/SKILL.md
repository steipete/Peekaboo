---
name: peekaboo-cli
description: Use Peekaboo's live CLI for macOS desktop automation: screenshots, UI maps, app/window control, clicking, typing, menus, clipboard, permissions, and MCP diagnostics. Use when a task needs current macOS UI state or direct desktop control.
allowed-tools: Bash(peekaboo:*), Bash(pkb:*), Bash(pnpm run docs:list:*), Bash(node scripts/docs-list.mjs:*)
---

# Peekaboo CLI

Peekaboo is a macOS automation CLI. Prefer the installed CLI and the repository's canonical docs over copied command references, because the command surface changes frequently.

## Start Here

1. Confirm the CLI and permissions before automation:
   ```bash
   peekaboo permissions status
   peekaboo list apps --json
   ```
2. For the latest agent-oriented guide, run:
   ```bash
   peekaboo learn
   ```
3. For the current tool catalog, run:
   ```bash
   peekaboo tools
   ```
4. When working inside the Peekaboo repo, find command docs with:
   ```bash
   node scripts/docs-list.mjs
   ```

## Canonical References

- Live CLI help: `peekaboo <command> --help`
- Full agent guide: `peekaboo learn`
- Tool catalog: `peekaboo tools`
- Command docs in this repo: `docs/commands/README.md` and `docs/commands/*.md`
- Permissions and bridge behavior: `docs/permissions.md`, `docs/bridge-host.md`, `docs/integrations/subprocess.md`

## Operating Rules

- Use `peekaboo see --json` before element interactions so you have fresh element IDs and snapshot IDs.
- Prefer element IDs from `see` for clicks and typing; use coordinates only when accessibility metadata is unavailable.
- Check `peekaboo permissions status` before assuming a capture or control failure is a CLI bug.
- Use `--json` when another tool or agent needs to parse results.
- Respect the user's desktop: avoid destructive app/window actions unless requested.
- If a command fails because the target UI changed, recapture with `peekaboo see --json` before retrying.

## Common Workflows

```bash
# Inspect current UI and save an annotated screenshot.
peekaboo see --json --annotate --path /tmp/peekaboo-ui.png

# Click an element discovered by see.
peekaboo click --on elem_42

# Type into the focused field.
peekaboo type "Hello from Peekaboo"

# Launch/focus an app, then inspect its windows.
peekaboo app launch "Safari"
peekaboo list windows --app Safari --json
```

Keep this skill small. Do not vendor generated command references here; update the canonical CLI docs or Commander metadata instead.
