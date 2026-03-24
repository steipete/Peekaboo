---
name: peekaboo-cli
description: macOS UI automation CLI tool for screen capture, window control, element clicking, text input, and more. Use when users need macOS desktop automation, UI testing, screen capture, window management, or app control.
allowed-tools: Bash(peekaboo:*)
---

# Peekaboo CLI

macOS UI automation command-line tool providing complete desktop control capabilities.

## Installation

Copy this skill to your agent's skills directory:

```bash
# Claude Code
mkdir -p ~/.claude/skills/peekaboo-cli
cp -r . ~/.claude/skills/peekaboo-cli/

# OpenClaw
mkdir -p ~/.openclaw/skills/peekaboo-cli
cp -r . ~/.openclaw/skills/peekaboo-cli/
```

## Prerequisites

- [Peekaboo CLI installed](https://github.com/steipete/Peekaboo#install) (`brew install steipete/tap/peekaboo`)
- macOS Screen Recording and Accessibility permissions granted

## Pre-execution Validation

Before executing any CLI commands, verify permission status first.

### 1. Check Permission Status

```bash
peekaboo permissions status
```

### 2. Grant Permissions (if needed)

If permissions are not granted, guide the user to enable them:

```
Peekaboo requires the following macOS permissions:
- Screen Recording: For capturing UI screenshots
- Accessibility: For controlling UI elements

System Settings → Privacy & Security → Screen Recording/Accessibility → Add Terminal app
```

Then verify:

```bash
peekaboo permissions grant
```

### 3. Verify Configuration

```bash
peekaboo list apps
```

## Quick Start

```bash
# List running applications
peekaboo list apps

# Capture current window UI with element annotations
peekaboo see --annotate --path /tmp/ui.png

# Click specific element (ID from see command)
peekaboo click --on elem_42

# Type text
peekaboo type "Hello World" --return
```

## Core Commands

### UI Capture & Analysis

```bash
# Capture UI element map (recommended before click/type)
peekaboo see --json --annotate --path /tmp/ui.png

# Target specific app/window
peekaboo see --app "Safari" --window-title "GitHub"

# Capture menubar popovers
peekaboo see --menubar

# Capture entire screen
peekaboo see --mode screen
```

### Element Interaction

```bash
# Click element by ID
peekaboo click --on elem_42
peekaboo click "Submit" --wait-for 8000

# Coordinate-based click
peekaboo click --coords 100,200

# Double-click / Right-click
peekaboo click --on elem_42 --double
peekaboo click --coords 100,200 --right

# Type text
peekaboo type "user@example.com" --return
peekaboo type --clear "new text"  # Clear field first

# Key presses and hotkeys
peekaboo press return
peekaboo hotkey "cmd,w"   # Cmd+W
```

### App Management

```bash
# Launch app
peekaboo app launch "Safari"
peekaboo app launch "Xcode" --open ~/Projects/MyApp.xcodeproj

# Quit app
peekaboo app quit --app "Safari"
peekaboo app quit --all --except "Finder,Terminal"

# Switch focus
peekaboo app switch --to Safari --verify
```

### Window Management

```bash
# List windows
peekaboo list windows --app "Safari" --include-details bounds,ids

# Move/Resize window
peekaboo window move --app Safari -x 100 -y 100
peekaboo window resize --app Safari -w 1200 --height 800

# Focus/Close/Minimize/Maximize
peekaboo window focus --app Terminal --space-switch
peekaboo window close --app Safari
```

### Menu Operations

```bash
# Click menu item
peekaboo menu click --app Safari --path "File,New Tab"

# List menubar status items
peekaboo list menubar
```

### Scroll & Drag

```bash
# Scroll
peekaboo scroll --direction down --amount 3

# Drag
peekaboo drag --from 100,100 --to 300,300

# Move mouse
peekaboo move --coords 500,500
```

## Common Workflows

### Form Filling

```bash
# 1. Capture UI to get element IDs
peekaboo see --json --annotate --path /tmp/form.png

# 2. Click input field and type
peekaboo click --on elem_10
peekaboo type "username" --tab
peekaboo type "password" --return
```

### App Automation

```bash
# 1. Launch app
peekaboo app launch "Safari" --wait-until-ready

# 2. Wait and perform actions
peekaboo sleep 2
peekaboo hotkey "cmd,l"  # Focus address bar
peekaboo type "https://github.com" --return
```

## Output Format

Most commands support `--json` output:

```bash
peekaboo see --json | jq '.data.ui_elements[] | {id, label, role}'
peekaboo list apps --json | jq '.data[] | select(.frontmost == true)'
```

## Troubleshooting

### Permission Errors

```bash
peekaboo permissions status
peekaboo permissions grant
```

### Element Not Found

1. Re-capture UI: `peekaboo see --json`
2. Use `--wait-for` to increase wait time
3. Use `--coords` for coordinate-based targeting

### Focus Issues

1. Use `--space-switch` for cross-Space windows
2. Use `peekaboo app switch --to <app> --verify` to confirm focus
3. Use `--no-auto-focus` when already focused manually

## Detailed Documentation

* **UI Capture** [references/see.md](references/see.md)
* **Element Click** [references/click.md](references/click.md)
* **Text Input** [references/type.md](references/type.md)
* **Key Press** [references/press.md](references/press.md)
* **Hotkey** [references/hotkey.md](references/hotkey.md)
* **App Management** [references/app.md](references/app.md)
* **Window Management** [references/window.md](references/window.md)
* **Menu Operations** [references/menu.md](references/menu.md)
* **Menubar** [references/menubar.md](references/menubar.md)
* **Scroll** [references/scroll.md](references/scroll.md)
* **Drag** [references/drag.md](references/drag.md)
* **Mouse Move** [references/move.md](references/move.md)
* **Swipe Gesture** [references/swipe.md](references/swipe.md)
* **Long-running Capture** [references/capture.md](references/capture.md)
* **Image Processing** [references/image.md](references/image.md)
* **Autonomous Agent** [references/agent.md](references/agent.md)
* **MCP Server** [references/mcp.md](references/mcp.md)
* **Config Management** [references/config.md](references/config.md)
* **Permissions** [references/permissions.md](references/permissions.md)
* **Clipboard** [references/clipboard.md](references/clipboard.md)
* **List Queries** [references/list.md](references/list.md)
* **Open Files** [references/open.md](references/open.md)
* **Sleep** [references/sleep.md](references/sleep.md)
* **Space Management** [references/space.md](references/space.md)
* **Dialog** [references/dialog.md](references/dialog.md)
* **Dock** [references/dock.md](references/dock.md)
* **Clean Cache** [references/clean.md](references/clean.md)
* **Bridge Service** [references/bridge.md](references/bridge.md)
* **Daemon** [references/daemon.md](references/daemon.md)
* **Tools** [references/tools.md](references/tools.md)
* **Learn** [references/learn.md](references/learn.md)
* **Run** [references/run.md](references/run.md)
* **MCP Capture Meta** [references/mcp-capture-meta.md](references/mcp-capture-meta.md)
* **Visualizer** [references/visualizer.md](references/visualizer.md)
