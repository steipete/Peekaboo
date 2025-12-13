---
summary: 'Index of Peekaboo CLI command docs'
read_when:
  - 'browsing available Peekaboo CLI commands'
  - 'linking to specific command docs'
---

# Command docs index

Core automation
- `agent.md` — run the autonomous agent loop.
- `app.md` — launch/quit/focus apps.
- `open.md` — open files/URLs with focus controls.
- `window.md` — move/resize/focus windows.
- `menu.md`, `menubar.md` — drive app menus and status items.
- `click.md`, `move.md`, `scroll.md`, `swipe.md`, `drag.md`, `press.md`, `type.md`, `hotkey.md`, `sleep.md` — input primitives.
- `see.md`, `image.md`, `capture.md`, `mcp-capture-meta.md` — screenshots, annotated UI maps, capture sessions.

System & config
- `config.md`, `permissions.md`, `bridge.md`, `tools.md`, `clean.md`, `run.md`, `learn.md`, `list.md`.
- MCP helpers: `mcp.md`.
- Clipboard: `clipboard.md`.

Reference tips
- Each command page lists flags, examples, and troubleshooting. For common pitfalls (permissions, focus, window targeting), see the “Common troubleshooting” section below.

## Common troubleshooting
- **Focus/foreground issues** — ensure the target app/window is focused (`peekaboo app focus ...`) and Screen Recording + Accessibility are granted (`peekaboo permissions status`).
- **Element not found** — run `peekaboo see --annotate` to verify AX labels/roles; fall back to coordinates with `--region` when needed.
- **Permission errors** — re-run `peekaboo permissions grant` and restart affected apps if dialogs persist.
- **Slow or flaky automation** — add `--quiet-ms`/`--heartbeat-sec` for capture/live commands; for input commands insert `--delay-ms` where available or precede with `sleep`.
