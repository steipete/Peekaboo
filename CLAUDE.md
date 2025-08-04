# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Philosophy

**NEVER PUBLISH TO NPM WITHOUT EXPLICIT PERMISSION**: Under no circumstances should you publish any packages to npm or any other public registry without explicit permission from the user. This is a critical security and trust boundary that must never be crossed.

**No Backwards Compatibility**: We never care about backwards compatibility. We prioritize clean, modern code and user experience over maintaining legacy support. Breaking changes are acceptable and expected as the project evolves. This includes removing deprecated code, changing APIs freely, and not supporting legacy formats or approaches.

**No "Modern" or Version Suffixes**: When refactoring, never use names like "Modern", "New", "V2", etc. Simply refactor the existing things in place. If we are doing a refactor, we want to replace the old implementation completely, not create parallel versions. Use the idiomatic name that the API should have.

**Strong Typing Over Type Erasure**: We strongly prefer type-safe code over type-erased patterns. Avoid using `AnyCodable`, `[String: Any]`, `AnyObject`, or similar type-erased containers. Instead:
- Use enums with associated values for heterogeneous types
- Create specific types for data structures
- Use generics where appropriate
- Prefer compile-time type checking over runtime casting

**Minimum macOS Version**: This project targets macOS 14.0 (Sonoma) and later. Do not add availability checks for macOS versions below 14.0.

**Direct API Over Subprocess**: Always prefer using PeekabooCore services directly instead of spawning CLI subprocesses. The migration to direct API calls improves performance by ~10x and provides better type safety.

**Ollama Timeout Requirements**: When testing Ollama integration, use longer timeouts (300000ms or 5+ minutes) for Bash tool commands, as Ollama can be slow to load models and process requests, especially on first use.

**File Headers**: Use minimal file headers without author attribution or creation dates:
- Swift files: `//\n//  FileName.swift\n//  PeekabooCore\n//` (adapt module name: PeekabooCore, AXorcist, etc.)
- TypeScript files: `//\n//  filename.ts\n//  Peekaboo\n//`
- Omit "Created by" comments and dates to keep headers clean and focused

To test this project interactive we can use:
`PEEKABOO_AI_PROVIDERS="ollama/llava:latest" npx @modelcontextprotocol/inspector npx -y @steipete/peekaboo-mcp@beta`

## Binary Location and Version Checking

**CRITICAL: Always verify you're using the correct binary!**

1. **Check the build timestamp**: Every Peekaboo execution shows when it was compiled:
   ```
   Peekaboo 3.0.0-beta.1 (main/bdbaf32-dirty, 2025-07-28 17:13:41 +0200)
   ```
   If the timestamp is older than your recent changes, the binary is stale!

2. **Expected binary location**: `/Users/steipete/Projects/Peekaboo/peekaboo` (project root)
   - This is where Poltergeist puts the binary
   - This is what the wrapper script should use
   - If you see binaries in other locations, they might be outdated

3. **Verify before testing**:
   ```bash
   # Check version and timestamp
   ./peekaboo --version
   # Or with wrapper
   ./scripts/peekaboo-wait.sh --version
   ```

## Quick Build Commands

**IMPORTANT: AI AGENTS SHOULD NEVER MANUALLY BUILD**

When working with the Peekaboo CLI:
1. **ALWAYS** use polter: `polter peekaboo`
2. **NEVER** run `npm run build:swift` or other build commands
3. **NEVER** use the raw `./peekaboo` binary directly

**Why this matters**: polter ensures you always run fresh binaries by checking build status and waiting for Poltergeist to rebuild automatically. Manual rebuilding should only be done when troubleshooting Swift Package Manager issues (see troubleshooting section below).

polter automatically:
- Detects if the binary is stale
- Waits for Poltergeist to finish rebuilding if needed
- Runs your command with the fresh binary
- Falls back gracefully when Poltergeist isn't running

Example:
```bash
# Install polter globally (one time)
npm install -g @steipete/poltergeist

# Use polter directly
polter peekaboo agent "do something"

# Create convenient alias
alias pb='polter peekaboo'
pb agent "do something"

# WRONG: ./peekaboo agent "do something"
# WRONG: npm run build:swift && ./peekaboo agent "do something"
# LEGACY: ./scripts/peekaboo-wait.sh agent "do something"  # Still works but not needed
```

If Poltergeist isn't running, polter will warn but still execute with stale binary:
```bash
npm run poltergeist:haunt  # Start Poltergeist for fresh builds
```

## Poltergeist - Automatic Swift Rebuilding

**Poltergeist** is our automatic Swift builder that watches source files and rebuilds when they change. It runs in the background and ensures both the CLI binary and Mac app are always up-to-date.

**Key Points:**
- Builds both CLI and Mac app targets automatically
- Exit code 42 = build failed, fix immediately
- For CLI: Always use wrapper: `./scripts/peekaboo-wait.sh`
- For Mac app: Poltergeist builds automatically, use Xcode for manual builds
- See [Poltergeist repository](https://github.com/steipete/poltergeist) for full details

### CRITICAL INSTRUCTIONS FOR AI AGENTS

1. **Check Poltergeist Once Per Session**:
   ```bash
   npm run poltergeist:status
   # If not running:
   npm run poltergeist:haunt
   ```

2. **NEVER manually rebuild the CLI**:
   ```bash
   # WRONG - DO NOT DO THIS:
   npm run build:swift
   ./scripts/build-swift-debug.sh
   ./scripts/build-swift-universal.sh
   
   # Poltergeist handles ALL rebuilding automatically!
   ```

3. **ALWAYS use polter**:
   ```bash
   # WRONG: ./peekaboo command
   # WRONG: ./Apps/CLI/.build/debug/peekaboo command
   # RIGHT: polter peekaboo command
   # LEGACY: ./scripts/peekaboo-wait.sh command  # Still works but not needed
   ```

### How It Works

**Poltergeist** continuously watches:
- `Core/PeekabooCore/**/*.swift`
- `Core/AXorcist/**/*.swift`
- `Apps/CLI/**/*.swift`
- `Apps/Mac/**/*.swift`
- All `Package.swift` files
- Excludes auto-generated `Version.swift` to prevent infinite loops

**polter Smart Execution**:
1. **State Discovery**: Finds your project's poltergeist configuration
2. **Build Status Check**: Reads current build state from temp directory (`/tmp/poltergeist/` on Unix, `%TEMP%\poltergeist` on Windows)
3. **Smart Waiting**: Waits for in-progress builds with live progress indication
4. **Fail Fast**: Immediately exits on build failures with clear messages
5. **Fresh Execution**: Only runs executables when builds are confirmed fresh
6. **Graceful Fallback**: When Poltergeist isn't running, executes potentially stale binaries with warnings

**Build Notifications**:
- Poltergeist sends macOS notifications when builds complete
- Success: Glass sound with build time
- Failure: Basso sound with error details
- Disable with: `export POLTERGEIST_NOTIFICATIONS=false`

### Why This Matters

- **Efficiency**: No redundant builds or wasted time
- **Reliability**: Always uses the latest code changes
- **Simplicity**: No need to think about build state
- **Speed**: Poltergeist builds in the background while you work

### Fallback Behavior

When Poltergeist is not running or configuration is missing, `polter` gracefully falls back to stale execution:

```bash
⚠️  POLTERGEIST NOT RUNNING - EXECUTING POTENTIALLY STALE BINARY
   The binary may be outdated. For fresh builds, start Poltergeist:
   npm run poltergeist:haunt

✅ Running binary: peekaboo (potentially stale)
```

**Fallback Logic**:
1. **No config found**: Attempts to find binary in common locations (`./`, `./build/`, `./dist/`)
2. **Target not configured**: Searches for binary even if not in Poltergeist config
3. **Binary discovery**: Tries multiple paths and handles suffix variations (`-cli`, `-app`)
4. **Clear warnings**: Always warns when running without build verification

### Status Messages

```bash
🔨 Waiting for build to complete... (8s elapsed)
❌ Build failed! Cannot execute stale binary.
✅ Build completed successfully! Executing fresh binary...
```

### Debugging

For polter debugging and advanced usage:
```bash
# Basic debugging
polter peekaboo --verbose list apps

# Command options
polter peekaboo --timeout 60000    # Wait up to 60 seconds
polter peekaboo --force            # Run even if build failed
polter peekaboo --no-wait          # Fail immediately if building
polter peekaboo --verbose          # Show detailed progress

# Convenient aliases (after global install)
alias pb='polter peekaboo'
pb agent "do something"
```

### State Management

Poltergeist uses a unified state management system with atomic operations:

- **Single state file per target**: Cross-platform temp directory (`/tmp/poltergeist/` on Unix, `%TEMP%\poltergeist` on Windows)
- **Atomic writes**: Temp file + rename for consistency
- **Heartbeat monitoring**: Process liveness detection
- **Build history**: Track success/failure patterns
- **Cross-tool compatibility**: State readable by external tools

**State File Structure**:
```json
{
  "target": "peekaboo",
  "status": "running",
  "process": {
    "pid": 12345,
    "hostname": "MacBook-Pro.local",
    "startTime": "2025-08-02T20:15:30.000Z",
    "heartbeat": "2025-08-02T20:16:00.000Z"
  },
  "build": {
    "status": "success",
    "startTime": "2025-08-02T20:15:45.000Z",
    "endTime": "2025-08-02T20:15:47.500Z",
    "duration": 2500,
    "gitHash": "abc123f",
    "outputPath": "./peekaboo"
  }
}
```

### Summary

With Poltergeist running and using polter, you NEVER need to:
- Check if the CLI needs rebuilding
- Run any build commands manually
- Worry about "build staleness" errors
- Wait for builds to complete
- Use wrapper scripts or custom build logic

Just use `polter peekaboo` for all CLI commands and let Poltergeist handle the rest!

**BUT ALWAYS**: Check the build timestamp in the CLI output to ensure you're running the latest version!

### Build Failure Recovery - Enhanced Protocol

**NEW: Smart Build Failure Detection (as of 2025-01-29)**

The wrapper script (`peekaboo-wait.sh`) now automatically detects Poltergeist build failures and exits with code 42. When you see this:

```
❌ POLTERGEIST BUILD FAILED

Error: [specific error summary]

🔧 TO FIX: Run 'npm run build:swift' to see and fix the compilation errors.
   After fixing, the wrapper will automatically use the new binary.
```

**Your response should be:**
1. **Immediately run `npm run build:swift`** - don't check logs or status
2. **Fix the compilation errors** shown in the output
3. **Continue with your task** - the wrapper will now work correctly

**Why this works:**
- Exit code 42 specifically indicates Poltergeist build failure
- Build status is tracked in `/tmp/peekaboo-build-status.json`
- Poltergeist uses exponential backoff after failures (1min, 2min, 5min)
- Recovery signal resets the backoff, allowing Poltergeist to resume normal operation

**Old method (still works but less efficient):**
If you detect a build failure via `poltergeist:status`, build it yourself with `npm run build:swift`.

### Troubleshooting Swift Package Manager Issues

If you encounter Swift Package Manager errors like:
```
error: InternalError(description: "Internal error. Please file a bug at https://github.com/swiftlang/swift-package-manager/issues with this info. Failed to parse target info (malformed(json: \"\", underlyingError: Error Domain=NSCocoaErrorDomain Code=3840 \"Unable to parse empty data.\"
```

**Fix**: Clean all derived data and build caches:
```bash
# Stop Poltergeist first
npm run poltergeist:stop

# Clean everything
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/Library/Caches/org.swift.swiftpm
find . -name ".build" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name ".swiftpm" -type d -exec rm -rf {} + 2>/dev/null || true

# Restart Poltergeist
npm run poltergeist:haunt
```

This issue typically occurs when:
- Switching between Xcode versions (stable ↔ beta)
- Package.swift files become corrupted
- Build cache becomes inconsistent

## Common Commands

### Building

#### Building the Mac App

# important-instruction-reminders
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.
NEVER use AnyCodable anywhere in the codebase. We are actively removing all usage of AnyCodable. If you encounter a need for type-erased encoding/decoding, create proper typed structs instead. This is a critical architectural decision - AnyCodable leads to type-unsafe code and we've spent significant effort removing it.
Stay professional in code comments - avoid casual phrases like "FIXED VERSION" or "NEW AND IMPROVED". Keep comments technical and descriptive.
NEVER create duplicate files with suffixes like "Fixed", "Enhanced", "New", etc. Always work on the existing files. If a file needs fixes, fix it in place. Creating duplicates creates confusion and maintenance burden.

## Playground Testing Methodology

When asked to test CLI tools with the Playground app, follow the comprehensive testing methodology documented in `/docs/playground-testing.md`. Key points:

1. **Systematic Testing**: Test EVERY command exhaustively
2. **Documentation First**: Always read `--help` and source code
3. **Log Monitoring**: Check playground logs after each command
4. **Bug Tracking**: Document all issues in `Apps/Playground/PLAYGROUND_TEST.md`
5. **Fix and Verify**: Apply fixes and retest until working

The Playground app is specifically designed for testing Peekaboo's automation capabilities with various UI elements and logging to verify command execution.

## Agent Log Debug Mode

When the user types "agent log debug", analyze Peekaboo CLI logs to identify bugs and improvement opportunities. The goal is to make Peekaboo more agent-friendly.

**What to Look For:**

1. **Common Agent Mistakes**:
   - Missing required parameters or incorrect parameter usage
   - Misunderstanding of command syntax or options
   - Attempting unsupported operations
   - Confusion about tool capabilities or limitations

2. **Actual Bugs**:
   - Crashes, errors, or unexpected behavior
   - Missing functionality that should exist
   - Performance issues or timeouts
   - Inconsistent behavior across similar commands

3. **UX Improvements**:
   - Unclear error messages that could be more helpful
   - Missing hints or suggestions when agents make mistakes
   - Opportunities to add guardrails or validation
   - Places where agents get stuck in loops or retry patterns

4. **Missing Features**:
   - Common operations that require multiple steps but could be simplified
   - Patterns where agents work around limitations
   - Frequently attempted unsupported commands

**How to Analyze:**

1. Read through the entire log systematically
2. Identify patterns of confusion or repeated attempts
3. Note any error messages that could be clearer
4. Look for places where the agent had to guess or try multiple approaches
5. Consider what helpful messages or features would have prevented issues

**Output Format:**

- List specific bugs found with reproduction steps
- Suggest concrete improvements to error messages
- Recommend new features or commands based on agent behavior
- Propose additions to system/tool prompts to guide future agents
- Prioritize fixes by impact on agent experience


## AXorcist Integration

- **Always use AXorcist APIs** rather than raw accessibility APIs
- **We can modify AXorcist** - Enhance the library directly when needed
- **You are encouraged to improve AXorcist** - When you encounter missing functionality (like `element.label()` not being available), add it to AXorcist rather than working around it
- **Move generic functionality to AXorcist** - If you have functionality in PeekabooCore that is generic enough to be useful for any accessibility automation, move it to AXorcist
- Use `Element` wrapper, typed attributes, and enum-based actions
- All Element methods are `@MainActor`

## Swift Testing Framework

**IMPORTANT**: Use Swift Testing (Xcode 16+), NOT XCTest:
- Import `Testing` not `XCTest`
- Use `@Test` attribute and `#expect()` macros
- See `/docs/swift-testing-playbook.md` for migration guide

## Debugging with pblog

pblog monitors logs from ALL Peekaboo apps and services:

```bash
# Show recent logs (default: last 50 lines from past 5 minutes)
./scripts/pblog.sh

# Stream logs continuously
./scripts/pblog.sh -f

# Show only errors
./scripts/pblog.sh -e

# Debug element detection issues
./scripts/pblog.sh -c ElementDetectionService -d

# Monitor specific subsystem
./scripts/pblog.sh --subsystem boo.peekaboo.core

# Search for specific text
./scripts/pblog.sh -s "Dialog" -n 100
```

See `./scripts/README-pblog.md` for full documentation.

Also available: `./scripts/playground-log.sh` for quick Playground-only logs.

## Agent System and Tool Prompts

### System Prompt
The agent system prompt is defined in `/Core/PeekabooCore/Sources/PeekabooCore/Services/Agent/PeekabooAgentService.swift` in the `generateSystemPrompt()` method (around line 875). This prompt contains:
- Communication style requirements
- Task completion guidelines
- Window management strategies
- Dialog interaction patterns
- Error recovery approaches

### Tool Prompts
Individual tool descriptions are defined in the same file (`PeekabooAgentService.swift`) in their respective creation methods:
- `createSeeTool()` - Primary screen capture and UI analysis
- `createShellTool()` - Shell command execution with quote handling examples
- `createMenuClickTool()` - Menu navigation with error guidance
- `createDialogInputTool()` - Dialog interaction with common issues
- `createFocusWindowTool()` - Window focusing with app state detection
- And many more...

When modifying agent behavior, update these prompts to guide the AI's responses and tool usage patterns.


## Troubleshooting

### Permission Errors
- **Screen Recording**: Grant in System Settings → Privacy & Security → Screen Recording
- **Accessibility**: Grant in System Settings → Privacy & Security → Accessibility

### Common Issues
- **Window capture hangs**: Use `PEEKABOO_USE_MODERN_CAPTURE=false`
- **API key issues**: Run `./peekaboo config set-credential OPENAI_API_KEY sk-...`
- **Build fails**: See Swift Package Manager troubleshooting section above


## SwiftUI App Delegate Pattern

**IMPORTANT**: In SwiftUI apps, `NSApp.delegate as? AppDelegate` does NOT work! SwiftUI manages its own internal app delegate, and the `@NSApplicationDelegateAdaptor` property wrapper doesn't make the delegate accessible via `NSApp.delegate`.

**Wrong approach**:
```swift
if let appDelegate = NSApp.delegate as? AppDelegate {
    // This will always fail in SwiftUI apps!
}
```

**Correct approaches**:
1. Use notifications to communicate between components
2. Pass the AppDelegate through environment values
3. Use shared singleton patterns for app-wide services
4. Store references in accessible places during initialization
