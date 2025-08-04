# Terminal User Interface (TUI) and Progressive Enhancement

Peekaboo's agent command features intelligent terminal detection and progressive enhancement, automatically providing the best possible user experience based on your terminal's capabilities.

## Overview

Instead of manual mode selection, Peekaboo automatically detects your terminal's capabilities and selects the optimal output mode:

- **Full TUI** for capable terminals with TermKit interface
- **Enhanced formatting** for color terminals with rich typography
- **Standard output** for basic terminals with colors and icons
- **Minimal mode** for CI environments and pipes

## Output Modes

### 🎮 TUI Mode (Automatic)
*Enabled for terminals ≥100x20 characters with color support*

Full terminal user interface with:
- **Progress Dashboard**: Real-time task progress, step count, duration, token usage
- **Status Sidebar**: Current tool execution, recent tool history with timing
- **Live Output**: Streaming tool execution results and AI messages
- **Enhanced Visuals**: Split-pane layout, progress bars, structured information

```
┌─── Agent Status ────────────────────────────────────────────────┐
│ Task: Take a screenshot of Safari and save it to desktop       │
│ Progress: ████████░░░░ 8/20 steps • 🕒 1m 23s • ⚒ 5 tools     │
└─────────────────────────────────────────────────────────────────┘
┌─ Tools & Status ─┐ ┌─ Output ─────────────────────────────────┐
│ 🎯 Current:       │ │ 14:32:15 🚀 Task started: Take a scr... │
│ 👁 see screen     │ │ 14:32:16 🤖 Using model: Claude Opus 4  │
│                   │ │ 14:32:17 👁 see: screen                 │
│ 📋 Recent Tools:  │ │ 14:32:19 ✓ Captured screen (3 buttons) │
│ ✓ see (1.2s)      │ │ 14:32:20 🖱 click: element B3          │
│ ✓ click (0.8s)    │ │ 14:32:21 ✓ Clicked 'Address Bar'       │
│ → type (running)  │ │ 14:32:22 ⌨️ type: 'screenshot tutorial' │
└───────────────────┘ └─────────────────────────────────────────┘
```

### ✨ Enhanced Mode (Automatic)
*Enabled for color terminals ≥80 characters wide*

Rich formatting with improved typography:
- Enhanced completion summaries with visual separators
- Better emoji usage (🧠 for thinking, ✅ for completion)
- Improved spacing and visual structure
- Contextual progress information

Example output:
```
🤖 Peekaboo Agent v3.0.0 using Claude Opus 4 (main/abc123, 2025-01-30)

👁 see screen ✅ Captured screen (dialog detected, 5 elements) (1.2s)
🖱 click 'OK' ✅ Clicked 'OK' in dialog (0.8s)

────────────────────────────────────────────────────────────
✅ Task Completed Successfully
📊 Stats: 2m 15s • ⚒ 5 tools, 1,247 tokens
────────────────────────────────────────────────────────────
```

### 🎨 Compact Mode (Legacy)
*Standard color terminals*

Current implementation with colors and icons:
- Ghost animation during thinking phases
- Colorized tool execution with status indicators
- Standard completion summaries

### 📋 Minimal Mode (Automatic)
*CI environments, pipes, and limited terminals*

Plain text, CI-friendly output:
- No colors or special characters
- Simple "OK/FAILED" status indicators
- Pipe-safe formatting for automation

Example output:
```
Starting: Take a screenshot of Safari
see screen OK Captured screen (1.2s)
click OK Clicked OK (0.8s)
Task completed in 2m 15s with 5 tools
```

## Terminal Detection

### Capabilities Analysis

Peekaboo performs comprehensive terminal capability detection:

```swift
struct TerminalCapabilities {
    let isInteractive: Bool      // isatty(STDOUT_FILENO)
    let supportsColors: Bool     // COLORTERM + TERM patterns
    let supportsTrueColor: Bool  // 24-bit color detection
    let supportsTUI: Bool        // Full TUI requirements
    let width: Int              // Real-time dimensions via ioctl
    let height: Int
    let termType: String?       // $TERM environment variable
    let isCI: Bool              // CI environment detection
    let isPiped: Bool           // Output redirection detection
}
```

### Detection Methods

**Color Support Detection**:
1. `COLORTERM` environment variable (most reliable)
2. `TERM` patterns (`xterm-256color`, `*-color`)
3. Known color-capable terminals
4. Platform-specific defaults (macOS terminals)

**CI Environment Detection**:
- Checks 20+ CI service environment variables
- GitHub Actions, GitLab CI, Travis, CircleCI, etc.
- Automatically uses minimal mode for automation

**Terminal Dimensions**:
- Real-time size detection via `ioctl(TIOCGWINSZ)`
- Fallback to `$COLUMNS`/`$LINES` environment variables
- Minimum size requirements for TUI mode (100x20)

## Manual Control

### Command Line Flags

Override automatic detection with explicit flags:

```bash
# Force specific output modes
peekaboo agent --force-tui "complex task"     # Force TUI even in limited terminals
peekaboo agent --simple "basic task"          # Force minimal output
peekaboo agent --no-color "ci task"          # Disable colors only

# Standard flags (unchanged)
peekaboo agent --quiet "silent task"         # Only final result
peekaboo agent --verbose "debug task"        # Full JSON debug info
```

### Environment Variables

Control output mode via environment variables:

```bash
# Explicit mode selection
export PEEKABOO_OUTPUT_MODE=enhanced
export PEEKABOO_OUTPUT_MODE=minimal

# Standard color controls
export NO_COLOR=1                    # Disable colors (forces minimal)
export FORCE_COLOR=1                 # Force color support
export CLICOLOR_FORCE=1              # Alternative color forcing
```

## Usage Examples

### Automatic Mode Selection

```bash
# Automatically selects best mode for your terminal
peekaboo agent "Take a screenshot and analyze the content"

# In a good terminal (iTerm2, Terminal.app): Uses TUI mode
# In SSH session with colors: Uses enhanced mode  
# In CI environment: Uses minimal mode
# When piped: Uses minimal mode
```

### Manual Overrides

```bash
# Force TUI for demonstration
peekaboo agent --force-tui "complex automation workflow"

# Force simple output for scripting
peekaboo agent --simple "automated task" | tee log.txt

# Disable colors for accessibility
NO_COLOR=1 peekaboo agent "task without colors"
```

### Environment-Specific Usage

```bash
# GitHub Actions (automatically minimal)
- run: peekaboo agent "CI automation task"

# Local development (automatically enhanced/TUI)
peekaboo agent "interactive development task"

# Docker container (automatically minimal)
docker run --rm app peekaboo agent "containerized task"
```

## Technical Implementation

### Progressive Enhancement Algorithm

1. **Explicit overrides** - User flags take highest priority
2. **Environment variables** - `NO_COLOR`, `FORCE_COLOR`, `PEEKABOO_OUTPUT_MODE`
3. **Context detection** - CI environments, pipes, non-interactive shells
4. **Capability analysis** - Terminal size, color support, TUI compatibility
5. **Optimal selection** - Best mode for detected capabilities

### Compatibility

**Supported Terminals**:
- **TUI Mode**: iTerm2, Terminal.app, Alacritty, Kitty, WezTerm
- **Enhanced Mode**: Most modern terminals with color support
- **Compact Mode**: Any terminal with ANSI color support
- **Minimal Mode**: Any terminal, text-only environments

**CI/Automation Support**:
- GitHub Actions, GitLab CI, Travis CI, CircleCI
- Jenkins, Azure Pipelines, Buildkite
- Docker containers, SSH sessions
- Shell pipes and redirections

### Debugging

View terminal detection details in verbose mode:

```bash
peekaboo agent --verbose "debug task"
# Shows:
# Terminal: xterm-256color (120x40) - interactive, colors, truecolor, TUI-capable
# Selected mode: TUI (full terminal interface)
```

## Benefits

### For Users
- **Zero configuration** - Optimal experience automatically
- **Universal compatibility** - Works everywhere
- **Enhanced productivity** - Rich visual feedback in capable terminals
- **Accessibility** - Respects color preferences and limitations

### For Automation
- **CI-friendly** - Automatic minimal mode for scripts
- **Pipe-safe** - Clean output for processing
- **Log-friendly** - Plain text for log analysis
- **Scriptable** - Predictable output formats

### For Development
- **Debugging support** - Verbose mode shows detection logic
- **Override options** - Force specific modes for testing
- **Environment awareness** - Adapts to deployment context
- **Future-proof** - Easy to add new modes or detection logic

The progressive enhancement system ensures that Peekaboo provides the best possible user experience across all terminal environments while maintaining complete backward compatibility and automation-friendly behavior.