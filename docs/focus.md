# Window Focus and Space Management

Peekaboo provides intelligent window focusing that works seamlessly across macOS Spaces (virtual desktops), ensuring your automation commands always target the correct window.

## Table of Contents

- [Overview](#overview)
- [How It Works](#how-it-works)
- [Automatic Focus Management](#automatic-focus-management)
- [Focus Options](#focus-options)
- [Window Focus Command](#window-focus-command)
- [Space Management](#space-management)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Technical Details](#technical-details)

## Overview

Starting with v3, Peekaboo includes comprehensive window focus management that:

- **Tracks window identity** across interactions using stable window IDs
- **Detects window location** across different Spaces
- **Switches Spaces automatically** when needed
- **Ensures window focus** before any interaction
- **Handles edge cases** like minimized windows, closed windows, and multi-display setups

This eliminates the need for manual window management in your automation scripts.

## How It Works

### Window Identity Tracking

Peekaboo uses multiple methods to track windows:

1. **CGWindowID** - A stable identifier that persists for the window's lifetime
2. **AXIdentifier** - Optional developer-provided stable ID (rarely available)
3. **Window Title** - Human-readable but can change
4. **Window Index** - Position-based, least stable

When you use the `see` command, Peekaboo stores the window's CGWindowID in the session, allowing subsequent commands to reliably target the same window even if its title changes or it moves between Spaces.

### Focus Flow

When you execute an interaction command (click, type, etc.), Peekaboo:

1. **Retrieves window info** from the current session
2. **Checks if window still exists** (handles closed windows gracefully)
3. **Detects which Space** contains the window
4. **Switches to that Space** if different from current
5. **Brings app to front** and focuses the specific window
6. **Verifies focus succeeded** before proceeding
7. **Executes your command** on the correctly focused window

## Automatic Focus Management

All interaction commands automatically handle focus:

```bash
# These commands all include automatic focus management:
peekaboo click "Submit"
peekaboo type "Hello world"
peekaboo scroll --direction down
peekaboo menu click --app Safari --item "New Tab"
peekaboo hotkey --keys "cmd,s"
peekaboo drag --from B1 --to T2
```

### Default Behavior

By default, Peekaboo will:
- ✅ Focus the target window before interaction
- ✅ Switch Spaces if the window is on a different desktop
- ✅ Wait up to 5 seconds for focus to complete
- ✅ Retry up to 3 times if focus fails
- ✅ Verify focus before proceeding

## Focus Options

All interaction commands support these focus-related options:

### `--no-auto-focus`
Disables automatic focus management (not recommended).

```bash
peekaboo click "Submit" --no-auto-focus
```

Use cases:
- When you've already manually focused the window
- For coordinate-based clicks that don't need window focus
- Testing or debugging focus issues

### `--focus-timeout <seconds>`
Sets how long to wait for focus operations (default: 5.0).

```bash
peekaboo type "Long text..." --focus-timeout 10
```

Use cases:
- Slow-loading applications
- Heavy system load
- Network-based apps that may be sluggish

### `--focus-retry-count <number>`
Sets how many times to retry focus operations (default: 3).

```bash
peekaboo click "Save" --focus-retry-count 5
```

Use cases:
- Unreliable applications
- System under heavy load
- Critical operations that must succeed

### `--space-switch`
Forces Space switching even if window appears to be on current Space.

```bash
peekaboo click "Login" --space-switch
```

Use cases:
- When macOS Space detection is unreliable
- Ensuring you're on the correct Space
- Debugging Space-related issues

### `--bring-to-current-space`
Moves the window to your current Space instead of switching to it.

```bash
peekaboo type "Hello" --bring-to-current-space
```

Use cases:
- Keeping your current workspace
- Consolidating windows from multiple Spaces
- Avoiding Space switch animations

## Window Focus Command

For explicit window management, use the `window focus` command:

```bash
# Basic usage - focus window and switch Space if needed
peekaboo window focus --app Safari

# Focus specific window by title
peekaboo window focus --app Chrome --window-title "Gmail"

# Control Space behavior
peekaboo window focus --app Terminal --space-switch never
peekaboo window focus --app "VS Code" --space-switch always

# Move window to current Space
peekaboo window focus --app TextEdit --move-here

# Skip focus verification for speed
peekaboo window focus --app Finder --no-verify
```

### Options

- `--app <name>` - Application name, bundle ID, or PID
- `--window-title <title>` - Specific window title (partial match)
- `--window-index <number>` - Window index (0-based)
- `--space-switch [auto|always|never]` - Space switching behavior
- `--move-here` - Move window to current Space
- `--no-verify` - Skip focus verification

## Space Management

Peekaboo provides comprehensive Space (virtual desktop) management:

### List Spaces

```bash
# List all user Spaces
peekaboo space list

# Include system and fullscreen Spaces
peekaboo space list --all

# JSON output
peekaboo space list --json-output
```

### Current Space Info

```bash
# Show current Space details
peekaboo space current
```

### Switch Spaces

```bash
# Switch to Space 2 (1-based numbering)
peekaboo space switch --to 2

# Switch without waiting for animation
peekaboo space switch --to 3 --no-wait
```

### Move Windows Between Spaces

```bash
# Move Safari to Space 3
peekaboo space move-window --app Safari --to 3

# Move specific window
peekaboo space move-window --app Chrome --window-title "Gmail" --to 2
```

### Find Windows

```bash
# Find which Space contains a window
peekaboo space where-is --app "Visual Studio Code"

# Find specific window
peekaboo space where-is --app Chrome --window-title "GitHub"
```

## Best Practices

### 1. Use Sessions

Always start with `see` to establish a session:

```bash
# Good: Establishes session with window tracking
peekaboo see --app Safari
peekaboo click "Login"
peekaboo type "username"

# Less reliable: No window tracking
peekaboo click "Login" --coords 100,200
```

### 2. Let Peekaboo Handle Focus

Don't manually manage windows:

```bash
# Don't do this:
peekaboo window focus --app Safari
peekaboo click "Submit"

# Do this instead (automatic focus):
peekaboo click "Submit"
```

### 3. Handle Space Switches Gracefully

Be aware that Space switching takes time:

```bash
# For critical operations, increase timeout
peekaboo click "Save" --focus-timeout 10

# Or move windows to avoid switching
peekaboo type "Important data" --bring-to-current-space
```

### 4. Test Cross-Space Workflows

Test your automation across different Space configurations:

```bash
# Test with window on different Space
peekaboo space move-window --app YourApp --to 2
peekaboo see --app YourApp  # Should auto-switch
peekaboo click "Test Button"
```

## Troubleshooting

### "Window in different Space" Error

This occurs when Space switching is disabled:

```bash
# Solution 1: Allow Space switching (default)
peekaboo click "Button"  # Will auto-switch

# Solution 2: Move window to current Space
peekaboo click "Button" --bring-to-current-space

# Solution 3: Manually switch first
peekaboo space switch --to 2
peekaboo click "Button"
```

### "Window not found" Error

The window may have been closed or minimized:

```bash
# Check if window still exists
peekaboo list windows --app YourApp

# For minimized windows, restore first
peekaboo window restore --app YourApp
peekaboo click "Button"
```

### "Focus timeout" Error

The window is taking too long to focus:

```bash
# Increase timeout
peekaboo click "Button" --focus-timeout 10

# Or increase retry count
peekaboo click "Button" --focus-retry-count 5
```

### Focus Not Working

If automatic focus isn't working:

```bash
# Debug with explicit focus
peekaboo window focus --app YourApp --verbose

# Check permissions
peekaboo list permissions

# Try without focus (for testing)
peekaboo click "Button" --no-auto-focus
```

## Technical Details

### Implementation

Focus management is implemented using:

- **CGWindowID** - Core Graphics window identifiers
- **CGSSpace APIs** - Private APIs for Space management
- **AXUIElement** - Accessibility APIs for window focus
- **NSWorkspace** - AppKit APIs for application activation

### Performance

- Focus operations typically complete in 50-200ms
- Space switching adds 200-500ms (animation time)
- Window ID lookup is O(1) when available
- Fallback to title search is O(n) where n = number of windows

### Limitations

1. **Multiple Displays** - Currently optimized for single display setups
2. **Full Screen Apps** - May have limited Space mobility
3. **Stage Manager** - Experimental support, may have edge cases
4. **Minimized Windows** - Cannot be focused directly (must restore first)

### Session Storage

Window information stored in sessions:

```json
{
  "windowID": 12345,
  "windowAXIdentifier": null,
  "bundleIdentifier": "com.apple.Safari",
  "applicationName": "Safari",
  "windowTitle": "Apple",
  "lastFocusTime": "2025-01-28T10:30:00Z"
}
```

This allows commands to quickly locate and focus the correct window without searching.

## See Also

- [GUI Automation Guide](gui-automation.md)
- [Space Command Reference](commands/space.md)
- [Window Command Reference](commands/window.md)
- [Troubleshooting Guide](troubleshooting.md)