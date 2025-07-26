# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Philosophy

**No Backwards Compatibility**: We never care about backwards compatibility. We prioritize clean, modern code and user experience over maintaining legacy support. Breaking changes are acceptable and expected as the project evolves.

**Minimum macOS Version**: This project targets macOS 14.0 (Sonoma) and later. Do not add availability checks for macOS versions below 14.0.

**Direct API Over Subprocess**: Always prefer using PeekabooCore services directly instead of spawning CLI subprocesses. The migration to direct API calls improves performance by ~10x and provides better type safety.

To test this project interactive we can use:
`PEEKABOO_AI_PROVIDERS="ollama/llava:latest" npx @modelcontextprotocol/inspector npx -y @steipete/peekaboo-mcp@beta`

## Quick Build Commands

**IMPORTANT: AI AGENTS SHOULD NEVER MANUALLY BUILD**

When working with the Peekaboo CLI:
1. **ALWAYS** use the wrapper script: `./scripts/peekaboo-wait.sh`
2. **NEVER** run `npm run build:swift` or other build commands
3. **NEVER** use the raw `./peekaboo` binary directly

**Why this matters**: I (Claude) manually rebuilt when I should have used the wrapper script. The wrapper would have detected the stale binary and waited for Poltergeist to rebuild it automatically. Manual rebuilding should only be done when troubleshooting Swift Package Manager issues (see troubleshooting section below).

The wrapper script automatically:
- Detects if the binary is stale
- Waits for Poltergeist to finish rebuilding if needed
- Runs your command with the fresh binary

Example:
```bash
# WRONG: ./peekaboo agent "do something"
# WRONG: npm run build:swift && ./peekaboo agent "do something"
# RIGHT: ./scripts/peekaboo-wait.sh agent "do something"
```

If Poltergeist isn't running (rare), the wrapper will tell you to start it:
```bash
npm run poltergeist:haunt
```

## Poltergeist - Automatic CLI Rebuilding

**IMPORTANT: Poltergeist is ONLY for CLI builds, NOT for the Mac app!**
- For Mac app builds, always use Xcode or `xcodebuild`
- Poltergeist only watches and rebuilds the CLI binary at `./peekaboo`

**What is Poltergeist?** 
Poltergeist is a file watcher that automatically rebuilds the Swift CLI whenever source files change. It's like a helpful ghost that ensures the CLI binary is always up-to-date without manual intervention.

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

3. **ALWAYS use the wrapper script**:
   ```bash
   # WRONG: ./peekaboo command
   # WRONG: ./Apps/CLI/.build/debug/peekaboo command
   # RIGHT: ./scripts/peekaboo-wait.sh command
   ```

### How It Works

**Poltergeist** continuously watches:
- `Core/PeekabooCore/**/*.swift`
- `Core/AXorcist/**/*.swift`
- `Apps/CLI/**/*.swift`
- All `Package.swift` files
- Excludes auto-generated `Version.swift` to prevent infinite loops

**The Wrapper Script** (`peekaboo-wait.sh`):
- Checks if binary is fresh (newer than Swift sources)
- If stale, waits for Poltergeist to finish rebuilding (max 3 minutes)
- Runs the CLI with your command once ready
- Completely transparent - no manual build management needed
- Shows progress updates every 10 seconds during long builds

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

### Debugging

For wrapper debugging:
```bash
PEEKABOO_WAIT_DEBUG=true ./scripts/peekaboo-wait.sh list apps
```

### Summary

With Poltergeist running and using the wrapper script, you NEVER need to:
- Check if the CLI needs rebuilding
- Run any build commands manually
- Worry about "build staleness" errors
- Wait for builds to complete
- Call `sleep` before using `peekaboo-wait.sh` (the wrapper waits automatically)

Just use `./scripts/peekaboo-wait.sh` for all CLI commands and let Poltergeist handle the rest!

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

## Recent Updates

- **Complete Responses API migration** (2025-01-26): Migrated exclusively to OpenAI Responses API, removing all Chat Completions API code. Updated tool format to use flatter structure. Added proper model-specific parameter handling (reasoning for o3/o4, temperature restrictions).

- **VibeTunnel integration** (2025-01-26): Added VibeTunnel terminal title management to agent command for better visibility across multiple Claude sessions. Terminal titles update automatically during task execution and tool calls.

- **OpenAI API parameter fix** (2025-01-26): Fixed OpenAI API compatibility by changing 'messages' parameter to 'input' in request encoding for all models. Added delightful ghost animation for agent thinking state.

- **Agent communication fix for o3 models** (2025-01-26): Strengthened system prompt to ensure o3 models communicate their thought process. Changed default reasoning effort from "high" to "medium" for better balance between reasoning and communication.

- **Poltergeist file watcher** (2025-01-26): Added ghost-themed file watcher that automatically rebuilds Swift CLI on source changes. Uses Facebook's Watchman for efficient native file watching. See "Poltergeist" section above.

- **Responses API migration** (2025-01-26): Completely migrated from Chat Completions API to Responses API for all models. The Responses API provides better streaming support, reasoning visibility for o3/o4 models, and unified handling across all supported models.

- **Direct API migration** (2025-01-25): Removed CLI subprocess execution in favor of direct PeekabooCore API calls, resulting in ~10x performance improvement. All Peekaboo apps now use the unified service layer.


## Common Commands

### Building

#### Building the Mac App

**IMPORTANT: Poltergeist does NOT build the Mac app! Use Xcode or xcodebuild for Mac app builds.**

```bash
# Open in Xcode (recommended for development)
open Apps/Peekaboo.xcworkspace

# Build from command line
xcodebuild -workspace Apps/Peekaboo.xcworkspace -scheme Peekaboo -configuration Debug build

# Build and run
xcodebuild -workspace Apps/Peekaboo.xcworkspace -scheme Peekaboo -configuration Debug build && \
  open ~/Library/Developer/Xcode/DerivedData/Peekaboo-*/Build/Products/Debug/Peekaboo.app
```

#### Building the CLI (handled by Poltergeist)

```bash
# Build TypeScript server
npm run build

# Build Swift CLI only (usually not needed - Poltergeist does this)
npm run build:swift

# Build everything (Swift CLI + TypeScript)
npm run build:all

# Build universal Swift binary with optimizations
./scripts/build-swift-universal.sh
```

**Note**: Swift builds can take 3-5 minutes on first build or clean builds due to dependency compilation. Subsequent incremental builds are much faster (10-30 seconds).

### Using the Swift CLI

**ALWAYS use the smart wrapper to avoid build staleness issues:**

```bash
# Create a convenient alias (add to your shell profile)
alias pb='./scripts/peekaboo-wait.sh'

# Examples:
pb image --app "Safari" --path screenshot.png
pb list apps --json-output
PEEKABOO_AI_PROVIDERS="openai/gpt-4.1" pb analyze image.png "What is shown in this image?"
pb config set-credential OPENAI_API_KEY sk-...
```

### Agent Command

The `peekaboo agent` command provides natural language automation capabilities through OpenAI integration:

```bash
# Basic usage
./peekaboo agent "Take a screenshot of Safari and save it to desktop"
./peekaboo agent "Click on the Submit button in the current window"

# Output modes
./peekaboo agent --quiet "Type hello world"        # Only show final result
./peekaboo agent --verbose "Close all windows"     # Full debug output
./peekaboo agent "Click login"                     # Default: compact colorized output with ghost animation

# Resume sessions
./peekaboo agent --resume                          # Continue last conversation
./peekaboo agent --resume abc123                   # Resume specific session ID
./peekaboo agent --list-sessions                   # Show available sessions
```

#### VibeTunnel Integration

The agent command automatically updates the terminal title using VibeTunnel (if installed) to provide visibility into current operations:

- **During execution**: Shows current tool being executed (e.g., "click: Submit button - Take screenshot of...")
- **On completion**: Shows "Completed: [task]"
- **On error**: Shows "Error: [task]"

This helps track multiple Claude Code sessions at a glance, especially useful when managing parallel automation tasks.


## OpenAI API Integration

### Supported Models (2025)
- **o3**, **o3-mini**, **o3-pro** - Advanced reasoning models with detailed thought process
- **o4-mini** - Next generation reasoning model
- **gpt-4.1**, **gpt-4.1-mini** - Latest models with 1M token context
- **gpt-4o**, **gpt-4o-mini** - Multimodal models (128K context)

**Note**: GPT-3.5 and GPT-4 models are NOT supported. Only modern models with Responses API support are available.

### API Requirements
- All models use the Responses API at `/v1/responses`
- Uses `max_output_tokens` parameter for all models
- o3/o4 models support reasoning parameters (effort: high/medium/low)
- o3/o4 models do NOT support temperature parameter
- Supports streaming responses with event-based format
- Tool format uses flatter structure (name at top level, not nested)

### Configuration
```bash
# Set API key
./peekaboo config set-credential OPENAI_API_KEY sk-...

# Use specific model
./peekaboo agent "do something" --model gpt-4.1
```

### References
- [OpenAI API Spec](https://app.stainless.com/api/spec/documented/openai/openapi.documented.yml)
- [Responses API Documentation](https://cookbook.openai.com/examples/responses_api/reasoning_items)

## Important Implementation Details

### Environment Variables
- `PEEKABOO_AI_PROVIDERS`: Configure AI backends (e.g., `openai/o3,ollama/llava:latest`)
- `PEEKABOO_LOG_LEVEL`: Control logging verbosity
- `OPENAI_API_KEY`: Required for OpenAI provider
- `PEEKABOO_USE_MODERN_CAPTURE`: Set to `false` to use legacy API if ScreenCaptureKit hangs

### Configuration
- Config directory: `~/.peekaboo/`
- Config file: `~/.peekaboo/config.json` (JSONC with comments)
- Credentials: `~/.peekaboo/credentials` (key=value, chmod 600)
- Precedence: CLI args > env vars > credentials > config > defaults



## AXorcist Integration

- **Always use AXorcist APIs** rather than raw accessibility APIs
- **We can modify AXorcist** - Enhance the library directly when needed
- Use `Element` wrapper, typed attributes, and enum-based actions
- All Element methods are `@MainActor`

## Swift Testing Framework

**IMPORTANT**: Use Swift Testing (Xcode 16+), NOT XCTest:
- Import `Testing` not `XCTest`
- Use `@Test` attribute and `#expect()` macros
- See `/docs/swift-testing-playbook.md` for migration guide

## Debugging with vtlog

```bash
# Show recent logs (default: last 50 lines from past 5 minutes)
./scripts/vtlog.sh

# Stream logs continuously
./scripts/vtlog.sh -f

# Show only errors
./scripts/vtlog.sh -e

# Debug overlay issues
./scripts/vtlog.sh -c OverlayManager -n 100
```

Also available: `./scripts/playground-log.sh` for Playground app logs.

## Agent System Prompt

The OpenAI agent system prompt is defined in `Apps/Mac/Peekaboo/Services/PeekabooToolExecutor.swift` in the `systemPrompt()` method. When modifying agent behavior, update this prompt to guide the AI's responses and tool usage patterns.


## Troubleshooting

### Permission Errors
- **Screen Recording**: Grant in System Settings → Privacy & Security → Screen Recording
- **Accessibility**: Grant in System Settings → Privacy & Security → Accessibility

### Common Issues
- **Window capture hangs**: Use `PEEKABOO_USE_MODERN_CAPTURE=false`
- **API key issues**: Run `./peekaboo config set-credential OPENAI_API_KEY sk-...`
- **Build fails**: See Swift Package Manager troubleshooting section above

