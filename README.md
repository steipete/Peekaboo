# Peekaboo 🫣 - Mac automation that sees the screen and does the clicks.

![Peekaboo Banner](https://raw.githubusercontent.com/steipete/peekaboo/main/assets/banner.png)

[![npm version](https://badge.fury.io/js/%40steipete%2Fpeekaboo-mcp.svg)](https://www.npmjs.com/package/@steipete/peekaboo-mcp)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS (Sonoma)](https://img.shields.io/badge/macOS-14.0%2B%20(Sonoma)-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org/)
[![Node.js](https://img.shields.io/badge/node-%3E%3D20.0.0-brightgreen.svg)](https://nodejs.org/)
[![Download for macOS](https://img.shields.io/badge/Download-macOS-black?logo=apple)](https://github.com/steipete/peekaboo/releases/latest)
[![Homebrew](https://img.shields.io/badge/Homebrew-steipete%2Ftap-tan?logo=homebrew)](https://github.com/steipete/homebrew-tap)
<a href="https://deepwiki.com/steipete/peekaboo"><img src="https://deepwiki.com/badge.svg" alt="Ask DeepWiki"></a>

Peekaboo brings high-fidelity screen capture, AI analysis, and complete GUI automation to macOS. Version 3 adds native agent flows and multi-screen automation across the CLI and MCP server.

## What you get
- Pixel-accurate captures (windows, screens, menu bar) with optional Retina 2x scaling.
- Natural-language agent that chains Peekaboo tools (see, click, type, scroll, hotkey, menu, window, app, dock, space).
- Menu and menubar discovery with structured JSON; no clicks required.
- Multi-provider AI: GPT-5.1 family, Claude 4.x, Grok 4-fast (vision), Gemini 2.5, and local Ollama models.
- MCP server for Claude Desktop and Cursor plus a native CLI; the same tools in both.
- Configurable, testable workflows with reproducible sessions and strict typing.

## Install
- macOS app + CLI (Homebrew):
  ```bash
  brew install steipete/tap/peekaboo
  ```
- MCP server (Node 20+, no global install needed):
  ```bash
  npx -y @steipete/peekaboo-mcp
  ```

## Quick start
```bash
# Capture full screen at Retina scale and save to Desktop
peekaboo image --mode screen --retina --path ~/Desktop/screen.png

# Click a button by label (captures, resolves, and clicks in one go)
peekaboo see --app Safari --json-output | jq -r '.data.session_id' | read SID
peekaboo click --on "Reload this page" --session "$SID"

# Run a natural-language automation
peekaboo "Open Notes and create a TODO list with three items"

# Run as an MCP server (Claude/Cursor)
npx -y @steipete/peekaboo-mcp
```

| Command | What it does | Docs |
| --- | --- | --- |
| see | Capture and annotate UI, return session + element IDs | [docs/commands/see.md](docs/commands/see.md) |
| click | Click by element ID, label, or coordinates | [docs/commands/click.md](docs/commands/click.md) |
| type | Enter text with pacing options | [docs/commands/type.md](docs/commands/type.md) |
| press | Special keys and sequences | [docs/commands/press.md](docs/commands/press.md) |
| hotkey | Modifier combos (cmd/ctrl/alt/shift) | [docs/commands/hotkey.md](docs/commands/hotkey.md) |
| scroll | Scroll views or elements | [docs/commands/scroll.md](docs/commands/scroll.md) |
| swipe | Smooth gesture-style drags | [docs/commands/swipe.md](docs/commands/swipe.md) |
| drag | Drag-and-drop between elements/coords | [docs/commands/drag.md](docs/commands/drag.md) |
| move | Position the cursor without clicking | [docs/commands/move.md](docs/commands/move.md) |
| window | Move/resize/focus windows and Spaces | [docs/commands/window.md](docs/commands/window.md) |
| app | Launch, quit, relaunch, switch apps | [docs/commands/app.md](docs/commands/app.md) |
| space | List or switch macOS Spaces | [docs/commands/space.md](docs/commands/space.md) |
| menu | List/click app menus and extras | [docs/commands/menu.md](docs/commands/menu.md) |
| menubar | Target status-bar items by name/index | [docs/commands/menubar.md](docs/commands/menubar.md) |
| dock | Interact with Dock items | [docs/commands/dock.md](docs/commands/dock.md) |
| dialog | Drive system dialogs (open/save/etc.) | [docs/commands/dialog.md](docs/commands/dialog.md) |
| image | Screenshot screen/window/menu bar (+analyze) | [docs/commands/image.md](docs/commands/image.md) |
| list | Enumerate apps, windows, screens, permissions | [docs/commands/list.md](docs/commands/list.md) |
| tools | Inspect native + MCP tools | [docs/commands/tools.md](docs/commands/tools.md) |
| config | Manage credentials/providers/settings | [docs/commands/config.md](docs/commands/config.md) |
| permissions | Check/grant required macOS permissions | [docs/commands/permissions.md](docs/commands/permissions.md) |
| run | Execute `.peekaboo.json` automation scripts | [docs/commands/run.md](docs/commands/run.md) |
| sleep | Millisecond delays between steps | [docs/commands/sleep.md](docs/commands/sleep.md) |
| clean | Prune sessions and caches | [docs/commands/clean.md](docs/commands/clean.md) |
| agent | Natural-language multi-step automation | [docs/commands/agent.md](docs/commands/agent.md) |
| mcp | Manage external MCP servers and serve Peekaboo | [docs/commands/mcp.md](docs/commands/mcp.md) |

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
- Requirements: macOS 14+, Xcode 16+/Swift 6.2, Node 20+ (Corepack/pnpm).
- Install deps: `pnpm install` then `pnpm run build:cli` or `pnpm run test:safe`.
- Lint/format: `pnpm run lint && pnpm run format`.

## License
MIT
