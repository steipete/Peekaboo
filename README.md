# Peekaboo 🫣 - Mac automation that sees the screen and does the clicks.

![Peekaboo Banner](assets/peekaboo.png)

[![npm package](https://img.shields.io/badge/npm_package-3.0.0--beta1-brightgreen?logo=npm&logoColor=white&style=flat-square)](https://www.npmjs.com/package/@steipete/peekaboo)
[![License: MIT](https://img.shields.io/badge/License-MIT-ffd60a?style=flat-square)](https://opensource.org/licenses/MIT)
[![macOS 15.0+ (Sequoia)](https://img.shields.io/badge/macOS-15.0%2B_(Sequoia)-0078d7?logo=apple&logoColor=white&style=flat-square)](https://www.apple.com/macos/)
[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white&style=flat-square)](https://swift.org/)
[![node >=22](https://img.shields.io/badge/node-%3E%3D22.0.0-2ea44f?logo=node.js&logoColor=white&style=flat-square)](https://nodejs.org/)
[![Download macOS](https://img.shields.io/badge/Download-macOS-000000?logo=apple&logoColor=white&style=flat-square)](https://github.com/steipete/peekaboo/releases/latest)
[![Homebrew](https://img.shields.io/badge/Homebrew-steipete%2Ftap-b28f62?logo=homebrew&logoColor=white&style=flat-square)](https://github.com/steipete/homebrew-tap)
[![Ask DeepWiki](https://img.shields.io/badge/Ask-DeepWiki-0088cc?style=flat-square)](https://deepwiki.com/steipete/peekaboo)

Peekaboo brings high-fidelity screen capture, AI analysis, and complete GUI automation to macOS. Version 3 adds native agent flows and multi-screen automation across the CLI and MCP server.
> Note: v3 is currently in beta (3.0.0-beta4) and has a few known issues; see the changelog for details.

## What you get
- Pixel-accurate captures (windows, screens, menu bar) with optional Retina 2x scaling.
- Natural-language agent that chains Peekaboo tools (see, click, type, scroll, hotkey, menu, window, app, dock, space).
- Menu and menubar discovery with structured JSON; no clicks required.
- Multi-provider AI: GPT-5.1 family, Claude 4.x, Grok 4-fast (vision), Gemini 2.5, and local Ollama models.
- MCP server for Claude Desktop and Cursor plus a native CLI; the same tools in both.
- Configurable, testable workflows with reproducible sessions and strict typing.
- Requires macOS Screen Recording + Accessibility permissions (see [docs/permissions.md](docs/permissions.md)).

## Install
- macOS app + CLI (Homebrew):
  ```bash
  brew install steipete/tap/peekaboo
  ```
- MCP server (Node 22+, no global install needed):
  ```bash
  npx -y @steipete/peekaboo
  ```

## Quick start
```bash
# Capture full screen at Retina scale and save to Desktop
peekaboo image --mode screen --retina --path ~/Desktop/screen.png

# Click a button by label (captures, resolves, and clicks in one go)
peekaboo see --app Safari --json-output | jq -r '.data.snapshot_id' | read SNAPSHOT
peekaboo click --on "Reload this page" --snapshot "$SNAPSHOT"

# Run a natural-language automation
peekaboo agent "Open Notes and create a TODO list with three items"

# Run as an MCP server (Claude/Cursor)
npx -y @steipete/peekaboo

# Minimal Claude Desktop config snippet (Developer → Edit Config):
# {
#   "mcpServers": {
#     "peekaboo": {
#       "command": "npx",
#       "args": ["-y", "@steipete/peekaboo"],
#       "env": {
#         "PEEKABOO_AI_PROVIDERS": "openai/gpt-5.1,anthropic/claude-opus-4"
#       }
#     }
#   }
# }
```

| Command | Key flags / subcommands | What it does |
| --- | --- | --- |
| [see](docs/commands/see.md) | `--app`, `--mode screen/window`, `--retina`, `--json-output` | Capture and annotate UI, return snapshot + element IDs |
| [click](docs/commands/click.md) | `--on <id/query>`, `--snapshot`, `--wait`, coords | Click by element ID, label, or coordinates |
| [type](docs/commands/type.md) | `--text`, `--clear`, `--delay-ms` | Enter text with pacing options |
| [press](docs/commands/press.md) | key names, `--repeat` | Special keys and sequences |
| [hotkey](docs/commands/hotkey.md) | combos like `cmd,shift,t` | Modifier combos (cmd/ctrl/alt/shift) |
| [scroll](docs/commands/scroll.md) | `--on <id>`, `--direction up/down`, `--ticks` | Scroll views or elements |
| [swipe](docs/commands/swipe.md) | `--from/--to`, `--duration`, `--steps` | Smooth gesture-style drags |
| [drag](docs/commands/drag.md) | `--from/--to`, modifiers, Dock/Trash targets | Drag-and-drop between elements/coords |
| [move](docs/commands/move.md) | `--to <id/coords>`, `--screen-index` | Position the cursor without clicking |
| [window](docs/commands/window.md) | `list`, `move`, `resize`, `focus`, `set-bounds` | Move/resize/focus windows and Spaces |
| [app](docs/commands/app.md) | `launch`, `quit`, `relaunch`, `switch`, `list` | Launch, quit, relaunch, switch apps |
| [space](docs/commands/space.md) | `list`, `switch`, `move-window` | List or switch macOS Spaces |
| [menu](docs/commands/menu.md) | `list`, `list-all`, `click`, `click-extra` | List/click app menus and extras |
| [menubar](docs/commands/menubar.md) | `list`, `click` | Target status-bar items by name/index |
| [dock](docs/commands/dock.md) | `launch`, `right-click`, `hide`, `show`, `list` | Interact with Dock items |
| [dialog](docs/commands/dialog.md) | `list`, `click`, `input`, `file`, `dismiss` | Drive system dialogs (open/save/etc.) |
| [image](docs/commands/image.md) | `--mode screen/window/menu`, `--retina`, `--analyze` | Screenshot screen/window/menu bar (+analyze) |
| [list](docs/commands/list.md) | `apps`, `windows`, `screens`, `menubar`, `permissions` | Enumerate apps, windows, screens, permissions |
| [tools](docs/commands/tools.md) | `--verbose`, `--json-output`, `--no-sort` | Inspect native Peekaboo tools |
| [config](docs/commands/config.md) | `init`, `show`, `add`, `login`, `models` | Manage credentials/providers/settings |
| [permissions](docs/commands/permissions.md) | `status`, `grant` | Check/grant required macOS permissions |
| [run](docs/commands/run.md) | `.peekaboo.json`, `--output`, `--no-fail-fast` | Execute `.peekaboo.json` automation scripts |
| [sleep](docs/commands/sleep.md) | `--duration` (ms) | Millisecond delays between steps |
| [clean](docs/commands/clean.md) | `--all-snapshots`, `--older-than`, `--snapshot` | Prune snapshots and caches |
| [agent](docs/commands/agent.md) | `--model`, `--dry-run`, `--resume`, `--max-steps`, audio | Natural-language multi-step automation |
| [mcp](docs/commands/mcp.md) | `serve` (default) | Run Peekaboo as an MCP server |

## Models and providers
- OpenAI: GPT-5.1 (default) and GPT-4.1/4o vision
- Anthropic: Claude 4.x
- xAI: Grok 4-fast reasoning + vision
- Google: Gemini 2.5 (pro/flash)
- Local: Ollama (llama3.3, llava, etc.)

Set providers via `PEEKABOO_AI_PROVIDERS` or `peekaboo config add`.

## Learn more
- Command reference: [docs/commands/](docs/commands/)
- Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Building from source: [docs/building.md](docs/building.md)
- Testing guide: [docs/testing/tools.md](docs/testing/tools.md)
- MCP setup: [docs/commands/mcp.md](docs/commands/mcp.md)
- Permissions: [docs/permissions.md](docs/permissions.md)
- Ollama/local models: [docs/ollama.md](docs/ollama.md)
- Agent chat loop: [docs/agent-chat.md](docs/agent-chat.md)
- Service API reference: [docs/service-api-reference.md](docs/service-api-reference.md)

## Development basics
- Requirements: macOS 15+, Xcode 16+/Swift 6.2. Node 22+ only if you run the pnpm docs/build helper scripts (core CLI/app/MCP are Swift-only).
- Install deps: `pnpm install` then `pnpm run build:cli` or `pnpm run test:safe`.
- Lint/format: `pnpm run lint && pnpm run format`.

## License
MIT
