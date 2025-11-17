---
summary: 'Cheat sheet for every Peekaboo CLI command grouped by category.'
read_when:
  - 'learning what each CLI subcommand does'
  - 'mapping agent tools to direct CLI usage'
---

# CLI Command Reference

Peekaboo’s CLI mirrors everything the agent can do. Commands share the same session cache and most support `--json-output` for scripting. Run `peekaboo` with no arguments to print the root help menu, and `peekaboo --version` at any time to see the embedded build/commit metadata that Poltergeist stamped into the binary.

Use `peekaboo <command> --help` for inline flag descriptions; this page links to the authoritative docs in `docs/commands/`.

## Vision & Capture

- [`see`](commands/see.md) – Capture annotated UI maps, produce session IDs, and optionally run AI analysis.
- [`image`](commands/image.md) – Save raw PNG/JPG captures of screens, windows, or menu bar regions; supports `--analyze` prompts.
- `watch` – Adaptive PNG capture that watches a screen/window/region, keeps changed frames plus a contact sheet.
- [`list`](commands/list.md) – Subcommands: `apps`, `windows`, `screens`, `menubar`, `permissions`.
- [`tools`](commands/tools.md) – Filter native vs MCP tools; group by server or emit JSON summaries.
- [`run`](commands/run.md) – Execute `.peekaboo.json` scripts (`--output`, `--no-fail-fast`).
- [`sleep`](commands/sleep.md) – Millisecond pauses between steps.
- [`clean`](commands/clean.md) – Remove session caches by ID, age, or all at once (`--dry-run` supported).
- [`config`](commands/config.md) – Subcommands: `init`, `show`, `edit`, `validate`, `set-credential`, `add-provider`, `list-providers`, `test-provider`, `remove-provider`, `models`.
- [`permissions`](commands/permissions.md) – `status` (default) and `grant` helpers for Screen Recording/Accessibility.
- [`learn`](commands/learn.md) – Print the complete agent guide (system prompt, tool catalog, Commander signatures).

## Interaction

- [`click`](commands/click.md) – Target elements by ID/query/coords with smart waits and focus helpers.
- [`type`](commands/type.md) – Send text and control keys; supports `--clear`, `--delay`, tab counts, etc.
- [`press`](commands/press.md) – Fire `SpecialKey` sequences with repeat counts.
- [`hotkey`](commands/hotkey.md) – Emit modifier combos like `cmd,shift,t` in one shot.
- [`scroll`](commands/scroll.md) – Directional scrolling with optional element targeting and smooth mode.
- [`swipe`](commands/swipe.md) – Gesture-style drags between IDs or coordinates (`--duration`, `--steps`).
- [`drag`](commands/drag.md) – Drag-and-drop across elements, coordinates, or Dock destinations with modifiers.
- [`move`](commands/move.md) – Position the cursor at coordinates, element centers, or screen center with optional smoothing.

## Windows, Menus, Apps, Spaces

- [`window`](commands/window.md) – Subcommands: `close`, `minimize`, `maximize`, `move`, `resize`, `set-bounds`, `focus`, `list`.
- [`space`](commands/space.md) – `list`, `switch`, `move-window` for Spaces/virtual desktops.
- [`menu`](commands/menu.md) – `click`, `click-extra`, `list`, `list-all` for application menus + menu extras.
- [`menubar`](commands/menubar.md) – `list` and `click` status-bar icons by name or index.
- [`app`](commands/app.md) – `launch`, `quit`, `relaunch`, `hide`, `unhide`, `switch`, `list`; `launch` now accepts repeatable `--open <url|path>` arguments (plus `--wait-until-ready`, `--no-focus`) to pass documents/URLs directly to the target app.
- [`open`](commands/open.md) – Enhanced macOS `open` that respects `--app/--bundle-id`, `--wait-until-ready`, `--no-focus`, and emits JSON payloads for scripting.
- [`dock`](commands/dock.md) – `launch`, `right-click`, `hide`, `show`, `list` Dock items.
- [`dialog`](commands/dialog.md) – `click`, `input`, `file`, `dismiss`, `list` system dialogs.

## Automation & Integrations

- [`agent`](commands/agent.md) – Natural-language automation with dry-run planning, resume, audio modes, and model overrides.
- [`mcp`](commands/mcp.md) – `serve`, `list`, `add`, `remove`, `enable`, `disable`, `info`, `test`, `call`, `inspect` (stub) for Model Context Protocol workflows.

Need structured payloads? Pass `--json-output` (where supported) or orchestrate multiple commands inside `.peekaboo.json` scripts executed via [`peekaboo run`](commands/run.md).
