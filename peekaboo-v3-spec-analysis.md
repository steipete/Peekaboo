# Peekaboo v3 Spec Analysis

## Overview

Peekaboo v3 represents a major evolution from a "ghost" tool (that can only see) to an "actor" tool (that can interact with the UI). The spec is defined in `/docs/specv3.md` and implemented across multiple Swift command files and TypeScript MCP tool wrappers.

## Core Architecture

### 1. CLI-First Design
- Primary product: `peekaboo` binary (Swift)
- Self-contained, distributable via Homebrew
- All functionality accessible through CLI commands
- MCP server is a thin wrapper around CLI

### 2. Session-Based State Management
- Process-isolated, file-based session cache
- Session ID = Process ID (PID)
- Session directory: `~/.peekaboo/session/<PID>/`
- Atomic directory operations for cache integrity
- Manual cleanup with `peekaboo clean --all-sessions`

## Command Syntax Reference

### 1. `see` Command
Primary vision command that captures screenshots and analyzes UI hierarchy.

**CLI Syntax:**
```bash
peekaboo see [options]
peekaboo see --app Safari
peekaboo see --mode screen
peekaboo see --window-title "GitHub"
peekaboo see --annotate
peekaboo see --analyze "Find login button"
```

**Options:**
- `--app <name>`: Target specific application
- `--window-title <title>`: Target specific window
- `--mode <mode>`: Capture mode (screen/window/frontmost)
- `--path <path>`: Output path for screenshot
- `--annotate`: Generate annotated screenshot
- `--analyze <prompt>`: Analyze with AI
- `--json-output`: Output in JSON format

**Output:**
Returns session ID and paths to screenshots/UI map.

### 2. `click` Command
Performs mouse clicks on UI elements.

**CLI Syntax:**
```bash
peekaboo click --on <element_id> --session-id <id> [options]
peekaboo click --coords <x,y> [options]
peekaboo click <query> --session-id <id> [options]
```

**Options:**
- `--on <id>`: Element ID from UI map (e.g., "B1")
- `--coords <x,y>`: Direct coordinates
- `--session-id <id>`: Session from 'see' command
- `--wait-for <ms>`: Wait timeout for element
- `--double`: Perform double-click
- `--right`: Perform right-click

### 3. `type` Command
Types text or sends keyboard input.

**CLI Syntax:**
```bash
peekaboo type <text> [options]
peekaboo type "Hello World"
peekaboo type "user@example.com" --return
peekaboo type --tab 3
```

**Options:**
- `--session <id>`: Session ID
- `--delay <ms>`: Delay between keystrokes
- `--return`: Press return after typing
- `--tab [count]`: Press tab
- `--escape`: Press escape
- `--delete`: Press delete
- `--clear`: Clear field first (Cmd+A, Delete)

**Note:** The command uses positional argument for text, not `--text` flag.

### 4. `scroll` Command
Performs scroll operations.

**CLI Syntax:**
```bash
peekaboo scroll --direction <dir> --amount <num> [options]
```

**Options:**
- `--direction <dir>`: Required. up/down/left/right
- `--amount <num>`: Required. Number of scroll units
- `--on <id>`: Optional element to scroll over
- `--session <id>`: Session ID
- `--delay <ms>`: Delay between scrolls
- `--smooth`: Use smooth scrolling

### 5. `hotkey` Command
Presses key combinations.

**CLI Syntax:**
```bash
peekaboo hotkey --keys <keys>
peekaboo hotkey --keys "cmd,c"
peekaboo hotkey --keys "cmd,shift,t"
```

**Options:**
- `--keys <keys>`: Required. Comma-separated keys
- `--hold-duration <ms>`: How long to hold keys

### 6. `swipe` Command
Performs drag/swipe gestures.

**CLI Syntax:**
```bash
peekaboo swipe --from <id> --to <id> --session-id <id>
peekaboo swipe --from-coords <x,y> --to-coords <x,y>
```

**Options:**
- `--from <id>`: Source element ID
- `--from-coords <x,y>`: Source coordinates
- `--to <id>`: Destination element ID
- `--to-coords <x,y>`: Destination coordinates
- `--session <id>`: Session ID
- `--duration <ms>`: Swipe duration (default: 500ms)

### 7. `run` Command
Executes batch scripts.

**CLI Syntax:**
```bash
peekaboo run <script.peekaboo.json> [options]
```

**Options:**
- `--output <path>`: Save results to file
- `--no-fail-fast`: Continue on errors
- `--verbose`: Show detailed execution

**Script Format (.peekaboo.json):**
```json
{
  "description": "Login automation script",
  "steps": [
    {
      "stepId": "capture-login",
      "comment": "Capture the login screen",
      "command": "see",
      "params": {
        "app": "Safari",
        "annotate": true
      }
    },
    {
      "stepId": "click-username",
      "command": "click",
      "params": {
        "on": "T1"
      }
    },
    {
      "stepId": "enter-username",
      "command": "type",
      "params": {
        "text": "user@example.com"
      }
    },
    {
      "stepId": "pause",
      "command": "sleep",
      "params": {
        "duration": 500
      }
    }
  ]
}
```

### 8. `sleep` Command
Pauses execution.

**CLI Syntax:**
```bash
peekaboo sleep <duration_ms>
peekaboo sleep 1000  # Sleep for 1 second
```

**Note:** Takes duration as positional argument, not as a flag.

## MCP Tool Mappings

The MCP server exposes these commands as tools with the following parameter mappings:

### MCP Tool Parameters

1. **see tool:**
   - `app_target`: Maps to `--app`
   - `path`: Maps to `--path`
   - `session`: Maps to `--session`
   - `annotate`: Maps to `--annotate`

2. **click tool:**
   - `query`: Positional argument
   - `on`: Maps to `--on`
   - `coords`: Maps to `--coords`
   - `session`: Maps to `--session-id`
   - `wait_for`: Maps to `--wait-for`
   - `double`: Maps to `--double`
   - `right`: Maps to `--right`

3. **type tool:**
   - `text`: Required, maps to positional argument
   - `on`: Maps to `--on`
   - `session`: Maps to `--session`
   - `clear`: Maps to `--clear`
   - `delay`: Maps to `--delay`
   - `wait_for`: Maps to `--wait-for`

4. **scroll tool:**
   - `direction`: Required, maps to `--direction`
   - `amount`: Required, maps to `--amount`
   - `on`: Maps to `--on`
   - `session`: Maps to `--session`
   - `delay`: Maps to `--delay`
   - `smooth`: Maps to `--smooth`

5. **hotkey tool:**
   - `keys`: Required, maps to `--keys`
   - `hold_duration`: Maps to `--hold-duration`

6. **swipe tool:**
   - `from`: Maps to `--from`
   - `to`: Maps to `--to`
   - `duration`: Maps to `--duration`
   - `steps`: Maps to `--steps`

7. **run tool:**
   - `script_path`: Positional argument
   - `session`: Maps to `--session`
   - `stop_on_error`: Inverse of `--no-fail-fast`
   - `timeout`: Maps to `--timeout`

8. **sleep tool:**
   - `duration`: Required, maps to positional argument

## Key Implementation Details

### Element ID Format
- Format: Role prefix + 1-based index (e.g., `B1`, `T1`)
- Prefixes:
  - `B`: Button
  - `T`: TextField/TextArea
  - `L`: Link
  - `M`: Menu
  - `C`: CheckBox
  - `R`: Radio
  - `S`: Slider
  - `G`: Generic/Group

### Coordinate Format
- Always specified as `x,y` (comma-separated)
- Example: `100,200` or `--coords 100,200`

### Session Management Flow
1. Call `see` command to capture and analyze UI
2. Extract `session_id` from response
3. Pass `session_id` to subsequent action commands
4. Session cache is automatically used for element lookups

### Actionability Checks
Before acting on elements, the system verifies:
1. Element is visible (`kAXHiddenAttribute` is false)
2. Element is enabled (`kAXEnabledAttribute` is true)
3. Element is on-screen (bounding box intersects screen bounds)

### Performance Targets
- `see` command: < 2 seconds
- Action commands: < 500ms
- Built-in auto-wait mechanism for reliability

## Error Handling

Standard error codes:
- `PERMISSION_DENIED_SCREEN_RECORDING`
- `PERMISSION_DENIED_ACCESSIBILITY`
- `APP_NOT_FOUND`
- `AMBIGUOUS_APP_IDENTIFIER`
- `WINDOW_NOT_FOUND`
- `ELEMENT_NOT_FOUND`
- `CAPTURE_FAILED`
- `FILE_IO_ERROR`
- `INVALID_ARGUMENT`