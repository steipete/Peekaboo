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

**Modern Swift Patterns**: Follow modern Swift/SwiftUI patterns:
- Use `@Observable` (iOS 17+/macOS 14+) instead of `ObservableObject`
- Avoid unnecessary ViewModels - keep state in views when appropriate
- Use `@State` and `@Environment` for dependency injection
- Embrace SwiftUI's declarative nature, don't fight the framework
- See `/Users/steipete/Projects/vibetunnel/apple/docs/modern-swift.md` for details

**Minimum macOS Version**: This project targets macOS 14.0 (Sonoma) and later. Do not add availability checks for macOS versions below 14.0.

**Direct API Over Subprocess**: Always prefer using PeekabooCore services directly instead of spawning CLI subprocesses. The migration to direct API calls improves performance by ~10x and provides better type safety.

**Ollama Timeout Requirements**: When testing Ollama integration, use longer timeouts (300000ms or 5+ minutes) for Bash tool commands, as Ollama can be slow to load models and process requests, especially on first use.

**Claude Opus 4.1 Availability**: Claude Opus 4.1 (model ID: `claude-opus-4-1-20250805`) is currently available and working. This is not a future model - it exists and functions properly as of August 2025.

**GPT-5 Availability**: GPT-5 (model ID: `gpt-5`) was released on August 7, 2025. It is now the default OpenAI model for Peekaboo agent tasks. The API offers three sizes: `gpt-5` (best for logic and multi-step tasks, 74.9% on SWE-bench), `gpt-5-mini` (cost-optimized), and `gpt-5-nano` (ultra-low latency). All models support 400K total context (272K input + 128K output tokens).

**GPT-5 Preamble Messages**: When instructed, GPT-5 outputs user-visible preamble messages before and between tool calls to update users on progress during longer agentic tasks. This makes complex operations more transparent by showing the AI's plan and progress at each step.

**GPT-5 Responses API**: GPT-5 uses OpenAI's Responses API (`/v1/responses`) which provides persisted reasoning across tool calls, leading to more coherent and efficient outputs. This API supports `reasoning_effort` (minimal/low/medium/high) and `verbosity` (low/medium/high) parameters for fine-tuned control.

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

## Quick Reference

```bash
# Core commands
polter peekaboo <command>    # Run CLI (NOT ./peekaboo)
./scripts/pblog.sh -f         # Stream logs
npm run poltergeist:status    # Check build status
alias pb='polter peekaboo'   # Add to ~/.zshrc

# Examples
polter peekaboo agent "take screenshot"
polter peekaboo list apps
polter peekaboo see --annotate
```

## Poltergeist Usage

**polter runs binaries, NOT commands. Poltergeist auto-builds when files change.**

### Commands
```bash
npm run poltergeist:status   # Check if running & build status
npm run poltergeist:haunt    # Start auto-builder
npm run poltergeist:stop     # Stop auto-builder
polter peekaboo <args>       # Run CLI (waits for fresh build)
```

### NEVER
- `polter wait` - doesn't exist
- `npm run build:swift` - Poltergeist does this
- `./peekaboo` - use `polter peekaboo`

### Workflow
1. Start: `npm run poltergeist:haunt`
2. Edit files → Poltergeist rebuilds automatically
3. Run: `polter peekaboo <command>`

### Build Failures
Exit code 42 = build failed. Fix: `npm run build:swift` once, then continue.

### State
- Location: `/tmp/poltergeist/{project}-{hash}-{target}.state`
- Contains: build status, timestamps, process info

### SPM Issues
Clean caches if corrupted: `rm -rf ~/Library/Developer/Xcode/DerivedData/* ~/Library/Caches/org.swift.swiftpm`

## Common Commands

### Building

#### Building the Mac App

# important-instruction-reminders
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.
NEVER use AnyCodable anywhere in the codebase. We are actively removing all usage of AnyCodable. If you encounter a need for type-erased encoding/decoding, create proper typed structs instead. This is a critical architectural decision - AnyCodable leads to type-unsafe code and we've spent significant effort removing it.
NEVER open Xcode projects or workspaces - the user already has them open. Use polter or xcodebuild to verify builds.
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

# important-instruction-reminders
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.