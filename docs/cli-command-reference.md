---
summary: 'Cheat sheet for every Peekaboo CLI command grouped by category.'
read_when:
  - 'learning what each CLI subcommand does'
  - 'mapping agent tools to direct CLI usage'
---

# CLI Command Reference

Peekaboo’s CLI mirrors everything the agent can do. Commands share the same session cache and most support `--json-output` for scripting.

## Capture & Core Utilities

- `image` – Capture screens, windows, frontmost apps, or regions; add `--analyze` for inline AI analysis.
- `see` – Generate annotated UI maps (Peekaboo IDs) across multiple displays with optional `--annotate` overlay.
- `list` – Enumerate applications, windows, sessions, or server status via flags like `--apps`, `--windows`, `--sessions`.
- `tools` – Display every native + MCP tool; filter (`--native-only`, `--mcp-only`, `--mcp <server>`), group, or emit JSON.
- `config` – Initialize/edit/show config + credentials, including `set-credential` helpers.
- `permissions` – Check/request screen-recording & accessibility entitlements.
- `learn` – Print the comprehensive guide (system prompt, tool catalog, best practices). Text-only; no JSON mode.
- `run` – Execute `.peekaboo.json` automation scripts with `--no-fail-fast` and `--output <path>`.
- `sleep` – Millisecond pauses (`peekaboo sleep 1500`).
- `clean` – Prune session caches via `--all-sessions`, `--older-than <hours>`, or `--session <id>` (supports `--dry-run`).

## Interaction Commands

- `click` – Target elements by ID/label/coordinates with built-in focus helpers.
- `type` – Send text (including escape sequences) into the active element; pass `--app <Name>` (or a session) so Peekaboo can guarantee focus before typing.
- `press` – Trigger keys (Return, Esc, arrows) with optional repeat counts.
- `hotkey` – Emit modifier combos like `cmd,c`.
- `scroll` – Scroll in any direction with granular steps and element targeting.
- `swipe` – Gesture-style drags with direction and distance controls.
- `drag` – Drag between elements/coordinates/apps with modifiers, duration, and smoothing.
- `move` – Move the cursor to coordinates or element centers (great for hover states).

## Window & System Management

- `window` – Focus, move, resize, snap, minimize, maximize, and inspect windows.
- `space` – List Spaces, switch desktops, or move windows across displays/Spaces.
- `menu` – Traverse application menus via `--item` or `--path`, including menu extras.
- `menubar` – List + click macOS status-bar icons by name or index.
- `app` – Launch/quit/hide/show apps; launches now focus the target by default, and `--no-focus` keeps launches in the background when needed (still supports bundle IDs + `--wait-until-ready`).
- `dock` – Launch from the Dock, right-click Dock items, show/hide the Dock.
- `dialog` – Handle system dialogs (click buttons, input text, select files, dismiss).

## Automation & Bridges

- `agent` – Natural-language automation with verbose tracing, dry runs, and session resume.
- `mcp` – Manage Peekaboo’s MCP persona: `serve`, `list`, `add`, `enable`, `disable`, `inspect`, etc.

Need structured payloads? Pass `--json-output` (where supported) or combine these commands inside `.peekaboo.json` scripts executed by `peekaboo run`.
