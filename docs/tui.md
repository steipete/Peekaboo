---
summary: 'Review Terminal Output Modes and Progressive Enhancement guidance'
read_when:
  - 'planning work related to terminal output modes and progressive enhancement'
  - 'debugging or extending features described here'
---

# Terminal Output Modes and Progressive Enhancement

Peekaboo's agent command automatically adjusts its output for modern terminals while staying CI-friendly.

> **Note**: The TermKit-based TUI was retired in November 2025. The agent now focuses on enhanced, compact, and minimal text output modes.

## Overview

Peekaboo automatically detects your terminal's capabilities and selects the optimal output mode:

- **Enhanced formatting** for color terminals with rich typography
- **Compact mode** for standard ANSI terminals
- **Minimal mode** for CI environments and pipes

You can still override the selection with `--quiet`, `--verbose`, `--simple`, or by setting `PEEKABOO_OUTPUT_MODE`.

## Output Modes

### ✨ Enhanced Mode (Automatic)
*Enabled for color terminals*

Provides rich formatting with improved typography:
- Structured completion summaries with visual separators
- Clear emoji usage (🧠 for thinking, ✅ for completion)
- Contextual progress information

```
👻 Peekaboo Agent v3.0.0-beta2 using Claude Opus 4.5 (main/abc123, 2025-01-30)

👁 see screen ✅ Captured screen (dialog detected, 5 elements) (1.2s)
🖱 click 'OK' ✅ Clicked 'OK' in dialog (0.8s)

────────────────────────────────────────────────────────────
✅ Task Completed Successfully
📊 Stats: 2m 15s • ⚒ 5 tools, 1,247 tokens
────────────────────────────────────────────────────────────
```

### 🎨 Compact Mode (Automatic)

Colorized output with status indicators for terminals that support ANSI colors:
- Ghost animation during thinking phases
- Colorized tool execution summary
- Familiar single-column layout

### 📋 Minimal Mode (Automatic)
*CI environments, pipes, and limited terminals*

Plain text, automation-friendly output:
- No colors or special characters
- Simple "OK/FAILED" status indicators
- Pipe-safe formatting for logs

```
Starting: Take a screenshot of Safari
see screen OK Captured screen (1.2s)
click OK Clicked OK (0.8s)
Task completed in 2m 15s with 5 tools
```

## Terminal Detection

Peekaboo performs comprehensive terminal capability detection:

```swift
struct TerminalCapabilities {
    let isInteractive: Bool      // isatty(STDOUT_FILENO)
    let supportsColors: Bool     // COLORTERM + TERM patterns
    let supportsTrueColor: Bool  // 24-bit color detection
    let width: Int               // Real-time dimensions via ioctl
    let height: Int
    let termType: String?        // $TERM environment variable
    let isCI: Bool               // CI environment detection
    let isPiped: Bool            // Output redirection detection
}
```

Key detection techniques:

- **Color support** via `COLORTERM`, `TERM`, and known terminal lists
- **CI detection** for GitHub Actions, GitLab CI, CircleCI, Jenkins, etc.
- **Terminal size** through `ioctl` with fallbacks to `COLUMNS`/`LINES`

The recommended mode is derived from these capabilities, but explicit flags and environment variables always take precedence.
