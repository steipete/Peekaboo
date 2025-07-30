# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Philosophy

**NEVER PUBLISH TO NPM WITHOUT EXPLICIT PERMISSION**: Under no circumstances should you publish any packages to npm or any other public registry without explicit permission from the user. This is a critical security and trust boundary that must never be crossed.

**No Backwards Compatibility**: We never care about backwards compatibility. We prioritize clean, modern code and user experience over maintaining legacy support. Breaking changes are acceptable and expected as the project evolves. This includes removing deprecated code, changing APIs freely, and not supporting legacy formats or approaches.

**Strong Typing Over Type Erasure**: We strongly prefer type-safe code over type-erased patterns. Avoid using `AnyCodable`, `[String: Any]`, `AnyObject`, or similar type-erased containers. Instead:
- Use enums with associated values for heterogeneous types
- Create specific types for data structures
- Use generics where appropriate
- Prefer compile-time type checking over runtime casting

**Minimum macOS Version**: This project targets macOS 14.0 (Sonoma) and later. Do not add availability checks for macOS versions below 14.0.

**Direct API Over Subprocess**: Always prefer using PeekabooCore services directly instead of spawning CLI subprocesses. The migration to direct API calls improves performance by ~10x and provides better type safety.

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
- `Apps/Mac/**/*.swift`
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
3. **Signal recovery**: After successful build, run `./scripts/poltergeist/poltergeist-signal-recovery.sh`
4. **Continue with your task** - the wrapper will now work correctly

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

## Recent Updates

- **Poltergeist Generic Target System** (2025-01-30): Migrated Poltergeist from hardcoded cli/macApp configuration to a flexible generic target system. Breaking change: Configuration now uses a 'targets' array instead of separate 'cli' and 'macApp' sections. Supports executable, app-bundle, library, framework, test, docker, and custom target types. Target names must contain only letters, numbers, hyphens, and underscores (no spaces). Enhanced logging, file-based locking, and improved error handling. Version bumped to 2.0.0.

- **Enhanced Build Failure Recovery** (2025-01-29): Implemented smart build failure detection in Poltergeist. The wrapper script now exits with code 42 when detecting build failures, providing clear error messages and recovery instructions. Added build status tracking (`/tmp/peekaboo-build-status.json`), exponential backoff for repeated failures, and recovery signal mechanism to reset Poltergeist after manual fixes.

- **Grok (xAI) support** (2025-01-27): Added full support for xAI's Grok models including grok-4-0709 (256K context), grok-3 series, and grok-2-vision. Uses OpenAI-compatible Chat Completions API at `https://api.x.ai/v1`. Supports X_AI_API_KEY or XAI_API_KEY environment variables. Parameter filtering for Grok 4 models (no frequencyPenalty, presencePenalty, or stop parameters). Default model shortcut: `grok` → `grok-4-0709`.

- **Dual API support** (2025-01-27): Restored Chat Completions API alongside Responses API. All models now default to Responses API for superior streaming support. Chat Completions API can be explicitly selected using `--api-mode chat` CLI parameter or `apiType` parameter in model settings. The Responses API is preferred as it provides better streaming capabilities for all models including GPT-4.1.

- **Anthropic SDK support** (2025-01-26): Added native Swift implementation for Anthropic's Claude models. Features full streaming support, tool calling, multimodal inputs, and all Claude 3/3.5/4 models. No external dependencies required.

- **O3 reasoning summaries** (2025-01-26): Fixed o3 model reasoning output by implementing support for reasoning summaries. Added handling for `response.reasoning_summary_text.delta` events and proper passing of `reasoning: { summary: "detailed" }` parameter to the API. Now displays "💭 Thinking: " prefix followed by actual reasoning summaries when available.


- **VibeTunnel integration** (2025-01-26): Added VibeTunnel terminal title management to agent command for better visibility across multiple Claude sessions. Terminal titles update automatically during task execution and tool calls.

- **OpenAI API parameter fix** (2025-01-26): Fixed OpenAI API compatibility by changing 'messages' parameter to 'input' in request encoding for all models. Added delightful ghost animation for agent thinking state.

- **Agent communication fix for o3 models** (2025-01-26): Strengthened system prompt to ensure o3 models communicate their thought process. Changed default reasoning effort from "high" to "medium" for better balance between reasoning and communication.

- **Poltergeist file watcher** (2025-01-26): Added ghost-themed file watcher that automatically rebuilds Swift CLI on source changes. Uses Facebook's Watchman for efficient native file watching. See "Poltergeist" section above.

- **Dual API support restored** (2025-01-27): Restored Chat Completions API alongside Responses API. All models now default to Responses API for better streaming support. API can be explicitly selected via `--api-mode` CLI parameter or `apiType` parameter in `additionalParameters`.

- **Direct API migration** (2025-01-25): Removed CLI subprocess execution in favor of direct PeekabooCore API calls, resulting in ~10x performance improvement. All Peekaboo apps now use the unified service layer.

- **Ollama integration** (2025-01-27): Added full Ollama support with tool/function calling capabilities. **llama3.3 is the recommended Ollama model** for agent tasks as it has excellent tool calling support. Vision models (llava, bakllava) do not support tool calling.


## Common Commands

### Building

#### Building the Mac App

**Note: Poltergeist now builds the Mac app automatically! You can still use Xcode or xcodebuild for manual builds.**

```bash
# Open in Xcode (recommended for development)
open Apps/Peekaboo.xcworkspace

# Build from command line
xcodebuild -workspace Apps/Peekaboo.xcworkspace -scheme Peekaboo -configuration Debug build

# Build and run
xcodebuild -workspace Apps/Peekaboo.xcworkspace -scheme Peekaboo -configuration Debug build && \
  open ~/Library/Developer/Xcode/DerivedData/Peekaboo-*/Build/Products/Debug/Peekaboo.app
```

#### Building the CLI and Mac App (handled by Poltergeist)

```bash
# Build TypeScript server
npm run build

# Build Swift CLI only (usually not needed - Poltergeist does this)
npm run build:swift

# Build Mac app only (usually not needed - Poltergeist does this)
npm run build:mac

# Build everything (Swift CLI + Mac app + TypeScript)
npm run build:all

# Build universal Swift binary with optimizations
./scripts/build-swift-universal.sh
```

**Note**: Swift builds can take 3-5 minutes on first build or clean builds due to dependency compilation. Subsequent incremental builds are much faster (10-30 seconds).

**Important for AI Agents**: When running build or test commands, increase the Bash tool timeout beyond the default 2 minutes:
- Use `timeout: 300000` (5 minutes) for `npm run build:swift` or `npm run build:all`
- Use `timeout: 180000` (3 minutes) for `npm test` or test commands that include Swift compilation
- The `prepublishOnly` hook in Server/package.json rebuilds Swift, so publishing may also need longer timeouts

### Running Tests

```bash
# Run all tests
swift test

# Run tests with filter (Swift Testing)
swift test --filter "ClickServiceTests"
swift test --filter "SpaceAware"

# Run tests for a specific package (from package directory)
cd Core/PeekabooCore
swift test

# Run tests with verbose output
swift test --verbose

# Run tests in parallel (default)
swift test --parallel

# Run tests with specific configuration
swift test -c release
```

**Important**: Tests use Swift Testing framework (not XCTest). The `--filter` option matches test suite or test names.

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

The `peekaboo agent` command provides natural language automation capabilities through AI model integration (OpenAI and Anthropic):

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

#### Performance Considerations

**Important**: Agent operations can be slow, especially when:
- Listing windows across multiple applications
- Interacting with apps that have many windows/tabs (like Safari)
- Performing complex multi-step automation tasks
- Waiting for UI elements to become available
- Iterating through accessibility elements

**Typical operation times**:
- Simple operations (click, type): 1-5 seconds
- Window listing (single app): 5-30 seconds
- Window listing (all apps): 30 seconds - 2 minutes
- Complex automation workflows: 2-5 minutes or more

The default timeouts may be insufficient for these operations. Agent tasks can take several minutes to complete, so be patient and don't assume a task has failed just because it's taking longer than expected. Window enumeration is particularly slow when done sequentially across multiple applications due to the accessibility API constraints.


## OpenAI API Integration

### Supported Models (2025)
- **o3**, **o3-mini**, **o3-pro** - Advanced reasoning models with detailed thought process
- **o4-mini** - Next generation reasoning model
- **gpt-4.1**, **gpt-4.1-mini** - Latest models with 1M token context
- **gpt-4o**, **gpt-4o-mini** - Multimodal models (128K context)

**Note**: GPT-3.5 and GPT-4 models are NOT supported. Only modern models (GPT-4o, GPT-4.1, o3, o4) are available.

### API Requirements
- **Dual API Support**: System automatically selects appropriate API:
  - Chat Completions API (`/v1/chat/completions`): Default for GPT-4o, GPT-4.1 models
  - Responses API (`/v1/responses`): Required for o3/o4 models, optional for others
- **API Selection**: Controlled via `apiType` parameter in model settings ("chat" or "responses")
- Chat Completions API uses `max_tokens`, Responses API uses `max_output_tokens`
- o3/o4 models support reasoning parameters (effort: high/medium/low) - Responses API only
- o3/o4 models do NOT support temperature parameter
- Both APIs support streaming responses with SSE format
- Tool format differs between APIs:
  - Chat Completions: Nested structure with `function` object
  - Responses: Flatter structure with name at top level

### Reasoning Summaries (o3/o4 models)
O3 and o4 models use advanced reasoning but don't expose raw chain-of-thought. Instead:
- You must opt in to reasoning summaries via the `reasoning` parameter
- Set `reasoning: { summary: "detailed" }` to request detailed summaries
- Summaries arrive via `response.reasoning_summary_text.delta` events during streaming
- Even with `summary: "detailed"`, summaries may be omitted for short reasoning
- The `reasoning_effort` parameter (high/medium/low) is separate from summaries

### Configuration
```bash
# Set API key
./peekaboo config set-credential OPENAI_API_KEY sk-...

# Use specific model (with lenient matching)
./peekaboo agent "do something" --model gpt-4.1
./peekaboo agent "do something" --model gpt-4    # Resolves to gpt-4.1
./peekaboo agent "do something" --model gpt      # Resolves to gpt-4.1
```

## Grok (xAI) API Integration

### Supported Models (2025)
- **grok-4** - Latest Grok 4 model (aliases: grok, grok4)
- **grok-4-0709** - Specific July 9, 2025 release
- **grok-4-latest** - Always points to newest Grok 4 features
- **grok-2-1212** - Grok 2 model (alias: grok2, grok-2)
- **grok-2-vision-1212** - Grok 2 with vision capabilities
- **grok-beta** - Beta generation with 128k context
- **grok-vision-beta** - Beta vision model

### Configuration
```bash
# Set API key (supports two environment variable names)
export X_AI_API_KEY=xai-...
# OR
export XAI_API_KEY=xai-...

# Or use credentials file
./peekaboo config set-credential X_AI_API_KEY xai-...

# Use Grok models
./peekaboo agent "do something" --model grok-4
./peekaboo agent "do something" --model grok      # Resolves to grok-4
./peekaboo agent "do something" --model grok4     # Resolves to grok-4
```

### Key Features
- Uses OpenAI-compatible Chat Completions API
- Endpoint: `https://api.x.ai/v1/chat/completions`
- Full streaming support
- Tool calling support
- Multimodal support (for vision models)
- Parameter filtering for Grok 4 (no frequencyPenalty, presencePenalty, stop)

### Important Notes
- Grok 4 models do not support `frequencyPenalty`, `presencePenalty`, or `stop` parameters
- Uses standard Chat Completions format, not Responses API
- Pricing and rate limits per xAI documentation

### References
- [OpenAI API Spec](https://app.stainless.com/api/spec/documented/openai/openapi.documented.yml)
- [OpenAI OpenAPI Spec](https://raw.githubusercontent.com/openai/openai-openapi/refs/heads/manual_spec/openapi.yaml)
- [Responses API Documentation](https://cookbook.openai.com/examples/responses_api/reasoning_items)

## Anthropic API Integration

### Current Models (2025)

**Claude 4 Series** (Latest Generation - Released May 2025):
- **Claude Opus 4** (`claude-opus-4-20250514`) - **DEFAULT MODEL**
  - Most powerful model, world's best coding model
  - Leads on SWE-bench (72.5%) and Terminal-bench (43.2%)
  - Supports extended thinking mode: `claude-opus-4-20250514-thinking`
  - Can work continuously for several hours on long-running tasks
  - Pricing: $15/$75 per million tokens (input/output)
  - Level 3 safety classification
- **Claude Sonnet 4** (`claude-sonnet-4-20250514`)
  - Cost-optimized general-purpose model
  - Supports extended thinking mode: `claude-sonnet-4-20250514-thinking`
  - Pricing: $3/$15 per million tokens (input/output)

**Claude 3.7 Series** (February 2025):
- **Claude 3.7 Sonnet** - Hybrid reasoning model with rapid/extended thinking modes
  - Knowledge cutoff: October 2024
  - Supports up to 128k output tokens

**Claude 3.5 Series** (Still Available):
- `claude-3-5-haiku` - Fast, cost-effective
- `claude-3-5-sonnet` - Balanced, includes computer use capabilities
- `claude-3-5-opus` - Previous generation flagship

**Note**: Claude 3.0 models (opus, sonnet, haiku) have been deprecated and are no longer available via the API.

### Configuration
```bash
# Set API key
./peekaboo config set-credential ANTHROPIC_API_KEY sk-ant-...

# Use Claude Opus 4 (default for Anthropic)
./peekaboo agent "analyze this code" --model claude-opus-4
./peekaboo agent "analyze this code" --model claude-4-opus      # Lenient matching
./peekaboo agent "analyze this code" --model claude-opus        # Resolves to Opus 4
./peekaboo agent "analyze this code" --model claude             # Defaults to Opus 4

# Use specific models
./peekaboo agent "quick task" --model claude-sonnet-4
./peekaboo agent "extended reasoning" --model claude-opus-4-thinking

# Environment variable usage
PEEKABOO_AI_PROVIDERS="anthropic/claude-opus-4-20250514" ./peekaboo analyze image.png "What is shown?"
```

### Features
- **Streaming Support**: Real-time response streaming with SSE
- **Tool Calling**: Full support for function calling
- **Multimodal**: Image analysis via base64 encoding
- **System Prompts**: Separate system parameter for instructions
- **Token Limits**: Configurable max_tokens (default 4096)
- **Extended Thinking**: Claude 4 models support thinking modes for complex reasoning
- **Long Task Support**: Claude 4 can work continuously for several hours

### Key Differences from OpenAI
- System prompts use separate `system` parameter, not a message
- Content blocks for multimodal messages
- Tool results sent as user messages with `tool_result` blocks
- Different streaming event types and format
- No support for image URLs (base64 only)
- Hybrid reasoning models offer both instant and extended thinking modes
- Claude 4 models support much longer task execution times

## Ollama Integration

### Recommended Model

**llama3.3** is the recommended Ollama model for agent tasks due to its excellent tool calling support:

```bash
# Using full model name
PEEKABOO_AI_PROVIDERS="ollama/llama3.3" ./scripts/peekaboo-wait.sh agent "Click on the Apple menu"

# Using shortcuts
PEEKABOO_AI_PROVIDERS="ollama/llama" ./scripts/peekaboo-wait.sh agent "Take a screenshot"
PEEKABOO_AI_PROVIDERS="ollama/llama3" ./scripts/peekaboo-wait.sh agent "Type hello world"
```

### Available Models

**Models with Tool Calling Support** (✅ Recommended for agent tasks):
- `llama3.3`, `llama3.3:latest` - Best overall for automation tasks
- `llama3.2`, `llama3.2:latest` - Good alternative
- `llama3.1`, `llama3.1:latest` - Older but reliable
- `mistral-nemo`, `mistral-nemo:latest` - Fast with tool support
- `firefunction-v2`, `firefunction-v2:latest` - Specialized for function calling
- `command-r-plus`, `command-r-plus:latest` - Strong reasoning with tools
- `command-r`, `command-r:latest` - Lighter version with tool support

**Vision Models** (❌ No tool calling support):
- `llava`, `llava:latest` - Vision model without tool support
- `bakllava`, `bakllava:latest` - Alternative vision model
- `llama3.2-vision:11b`, `llama3.2-vision:90b` - Larger vision models
- `qwen2.5vl:7b`, `qwen2.5vl:32b` - Qwen vision models

**Other Language Models** (⚠️ Tool support varies):
- `devstral` - No tool support, text-only responses
- `mistral`, `mixtral` - May have limited tool support
- `codellama` - Code-focused model
- `deepseek-r1:8b`, `deepseek-r1:671b` - DeepSeek models

### Configuration

```bash
# Ollama runs locally, no API key needed
# Default base URL: http://localhost:11434

# Custom Ollama server
PEEKABOO_OLLAMA_BASE_URL="http://remote-server:11434" ./scripts/peekaboo-wait.sh agent "task"
```

### Important Notes

1. **Tool Calling**: Not all Ollama models support tool/function calling. Models that don't support tools will return HTTP 400 errors. Check the model list above for compatibility.
2. **Performance**: Local models may be slower than cloud APIs, especially for large models. The first response may take 30-60 seconds while the model loads.
3. **Memory**: Large models like llama3.3 (70B parameters) require significant RAM/VRAM.
4. **Timeouts**: Ollama requests have a 5-minute timeout to accommodate model loading and processing time.
5. **Streaming**: Ollama supports streaming responses, showing text as it's generated.
6. **Tool Call Format**: Some models (like llama3.3) output tool calls as JSON text in the content field rather than using the `tool_calls` field. Peekaboo automatically detects and parses these.

## Important Implementation Details

### Default Model Selection

**The default model for Peekaboo agent is Claude Opus 4** (`claude-opus-4-20250514`), Anthropic's most capable model for coding and complex reasoning tasks. To use a different model, specify it with the `--model` flag or set the `PEEKABOO_AI_PROVIDERS` environment variable.

**For Ollama users**: The recommended model is **llama3.3** which has excellent tool calling support for automation tasks:
```bash
# Use llama3.3 for agent tasks
PEEKABOO_AI_PROVIDERS="ollama/llama3.3" ./scripts/peekaboo-wait.sh agent "your task"

# Shorthand also works
PEEKABOO_AI_PROVIDERS="ollama/llama" ./scripts/peekaboo-wait.sh agent "your task"  # Defaults to llama3.3
```

### Environment Variables
- `PEEKABOO_AI_PROVIDERS`: Configure AI backends (e.g., `openai/o3,anthropic/claude-opus-4-20250514`)
- `PEEKABOO_LOG_LEVEL`: Control logging verbosity
- `OPENAI_API_KEY`: Required for OpenAI provider
- `ANTHROPIC_API_KEY`: Required for Anthropic provider
- `PEEKABOO_USE_MODERN_CAPTURE`: Set to `false` to use legacy API if ScreenCaptureKit hangs

### Configuration
- Config directory: `~/.peekaboo/`
- Config file: `~/.peekaboo/config.json` (JSONC with comments)
- Credentials: `~/.peekaboo/credentials` (key=value, chmod 600)
- Precedence: CLI args > env vars > credentials > config > defaults

### Threading and MainActor

**IMPORTANT: Almost everything in Peekaboo runs on the main thread.** This is by design because:

- **UI Operations**: All UI automation must run on the main thread
- **Accessibility APIs**: All AX (accessibility) operations are main thread only
- **AppleScript**: Requires main thread execution
- **Core Graphics Events**: Mouse/keyboard event simulation is main thread only
- **Screen Capture**: Most screen capture APIs (except the very newest ones) are synchronous and main thread only

This means:
- **Be liberal with @MainActor annotations** - When in doubt, mark it @MainActor
- **Don't worry about blocking the main thread** - These APIs are inherently synchronous anyway
- **Avoid unnecessary async/await for UI operations** - They're going to run on main thread regardless
- **Performance comes from efficient API usage**, not from threading

The only operations that might benefit from background threads are:
- Network requests to AI providers
- File I/O for large files
- Image processing after capture



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
The agent system prompt is defined in `/Core/PeekabooCore/Sources/PeekabooCore/Services/AgentService/PeekabooAgentService.swift` in the `generateSystemPrompt()` method (around line 875). This prompt contains:
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

