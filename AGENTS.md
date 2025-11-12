# AGENTS.md

This file provides guidance to our automation agents (Claude Code, GPT-5, and friends) when working with code in this repository.

## Project Status (November 5, 2025)

- **Dependency refresh**: local `Commander` package (replaces swift-argument-parser), `swift-async-algorithms 1.0.4`, `swift-collections 1.3.0`, `swift-crypto 3.15.1`, `swift-system 1.6.3`, plus `swift-sdk 0.10.2` (official MCP release) across PeekabooCore/Tachikoma/Apps.
- **Code updates**: centralized `LanguageModel.parse` in Tachikoma, replaced ad-hoc agent glyphs with `AgentDisplayTokens`, removed TermKit TUI hooks from CLI, default agent model now `gpt-5-mini`, emojis toned down in agent output, and Mac icon assets/resources registered for SwiftPM.
- **Verification**: `swift build` clean for Tachikoma, PeekabooCore, peekaboo CLI, and macOS app; `swift test --filter TypeCommandTests` currently hits a Swift frontend signal 5 (compiler bug) even outside tmux—log captured for follow-up. Other large suites remain gated by `RUN_LOCAL_TESTS=true`.
- **Next steps**: file Swift compiler crash with stack dump, add test subsets so automation suites compile in smaller batches, and revisit `tmux`-logged test strategy once the compiler issue is resolved.
- **CI note**: when running long Swift test suites use bare `tmux new-session …` invocations (no `while` loops or `tmux wait-for` wrappers). Continuous polling prevents our hang detector from spotting stuck jobs, which defeats the reason we run tests inside tmux. When implementing progress checks or back-off behaviour, cap individual `sleep`/timeout intervals at **≤30s** so the hang detector retains sufficient cadence.
- **CI monitoring**: use the GitHub CLI to inspect jobs instead of guessing. Examples: `gh run list --workflow "macOS CI" --limit 5` to see recent runs and `gh run view <run-id> --log` (or `--job <job-id> --log`) to stream detailed logs when a step fails.
- **Package manager**: we use `pnpm` for every JS/TS script or dependency install. Never call `npm install`, `npm run`, or `yarn` inside this repo—replace those with the equivalent `pnpm` command (e.g., `pnpm run poltergeist:haunt`).
- **tmux usage**: Avoid `while tmux …` polling or `tmux wait-for`; prefer direct `tmux` commands with occasional bounded `sleep` calls, and investigate any `tmux`-run command that approaches 10 minutes rather than letting it run unattended.
- **Log streaming**: Any `log stream`, `log show --style live`, or similar tail that can run longer than a few seconds **must** run inside tmux via the runner (e.g., `./runner tmux new-session -- log stream …`). Running those directly will hang the harness and crash your session.
- **Runner vs tmux**: Use the runner *or* tmux for a command, not both. If the task requires tmux, invoke `tmux` directly with the runner’s `./runner tmux …` wrapper; don’t nest additional runner layers inside the tmux command.
- **Loops & polling**: Never write open-ended `while` loops (especially in test scripts) that can block indefinitely. Always bound the iteration count or timeout (e.g., break after N checks) so hung processes can’t stall the agent forever, and when polling tmux/test status pick a sleep interval ≤30s so the hang detector still gets signal. \
  **New rule:** Any loop that waits on tool/test completion must cap its total wait time at **≤60s** before surfacing progress. Use tmux plus short `sleep` bursts (e.g., spawn the job with `tmux new-session …` and poll with `sleep 5` / `sleep 10` up to a minute) rather than camping in one `while` forever. After 60 seconds, print/log status, re-evaluate, or exit—never leave a background loop unattended.
- **Docs intake**: Kick off each session with `pnpm run docs:list` (runs `scripts/docs-list.mjs`) so you see the curated summaries/read-when hints for this repo. Open every doc that matches your task, keep it nearby while implementing, and add/update the front matter block (`---`, `summary: '...'`, `read_when:` bullets) any time you touch or create a doc so the helper keeps surfacing accurate guidance.
- **Agent model choice**: When validating agentic flows end-to-end, prefer OpenAI GPT-5 or Anthropic Claude Sonnet 4.5—those two models currently give the most reliable Peekaboo behavior and should be the baseline for deep debugging. Other Tachikoma models remain allowed (and are great for smoke tests or repro attempts), so keep overrides flexible when writing tooling; just default your own test passes to GPT-5/Sonnet 4.5 unless there’s a specific reason to cover another provider.
- **Commit discipline**: Batch related changes before committing. Never commit single files opportunistically—coordinate commit groups so parallel agents aren’t surprised by partially landed work.
- **Committer script**: All commits must go through `./scripts/committer "type(scope): subject" "path/to/file1" "path/to/file2"`. Pass the commit message as the first quoted argument, list every file path after it (also quoted), and let the helper manage staging—never run `git add` manually. The script validates paths, clears the index, re-stages only the listed files, and then creates the commit so you can land exactly what you expect.
- **Version control hygiene**: Never revert or overwrite files you did not edit. Other agents and humans may be working in parallel, so avoid destructive operations (including `git checkout`, `git reset`, or similar) unless explicitly instructed.
- **Git via runner**: The only git commands you may run are `status`, `diff`, `log`, and (when explicitly requested) `push`, and every one of them must go through the wrapper (`./runner git status -sb`, etc.). If the user types a guarded subcommand like “rebase,” include `RUNNER_THE_USER_GAVE_ME_CONSENT=1` in the same command before invoking `./runner git rebase …`. Destructive git operations remain forbidden without written approval in this thread.
- **Commander subrepo exception (Nov 11, 2025)**: The Commander package inside `/Commander` has its own `.git`. The user explicitly authorized running native `git add/commit/push` inside that subrepository when needed, since `./scripts/committer` only targets the root repo. Continue using `./runner git …` for the main Peekaboo tree unless the user renews this exception.
- **Custom dependency forks**: Commander now lives in `/Commander` and is shared across every package. Don’t reintroduce swift-argument-parser—the old fork is gone.
- **Submodule safety**: Peter edits `Tachikoma/` directly. Never run destructive git commands (`git checkout -- .`, `git reset --hard`, etc.) inside Tachikoma without his explicit approval.
- **Runner awareness**: Any task that regularly runs longer than ~1 minute (heavy builds, lint, long tests) must use the extended runner window—update the runner keyword list whenever a new long job appears so CI doesn’t evict your work.
- **Runner wrapper**: Run every build, test, package script, tmux-managed command, and git invocation through `./runner <command>` so the guardrails enforce timeouts and git policies. Only lightweight read-only utilities (`rg`, `sed`, `ls`, `cat`, etc.) may bypass it. Pass script flags after `--` (e.g., `./runner pnpm test -- --run`) and pay attention when the wrapper asks you to move multi-minute work into tmux.
- **Peeking at upstream files**: When you need to inspect another revision, redirect the file into `/tmp/` (or another scratch path) for reference. Never overwrite tracked files via redirection; copy the necessary hunks back with `apply_patch` so in-progress edits stay intact.
- **Crash reports**: When something crashes, grab the official `.ips` log immediately so we don’t fight “couldn’t reproduce”. Quick playbook:
  1. `ls -t ~/Library/Logs/DiagnosticReports | head` to find the newest `Peekaboo-*.ips` file, then `sed -n '1,120p' ~/Library/Logs/DiagnosticReports/<name>.ips` to inspect it.
  2. Console.app → Crash Reports is the GUI equivalent (right-click → Reveal in Finder if you need the file).
  3. For scripting/CI, `log show --last 5m --predicate 'process == "Peekaboo" && eventMessage CONTAINS "Crashed"'` surfaces the same info without hunting for files.
  4. Attach the `.ips` (or the relevant excerpt) to the GitHub issue/PR so the next person doesn’t have to ask where the crash came from.

## Custom Forks / Dependencies

- **Commander module**: use the in-repo `Commander` package (path dependency). It already carries the approachable-concurrency annotations we need; do not reintroduce swift-argument-parser.

### Commit Messages

We **always** use [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/). Stick to the format `<type>(<optional scope>)!: <description>` using the allowed types `feat|fix|refactor|build|ci|chore|docs|style|perf|test`.

Examples you can copy:
- `feat: Prevent racing of requests`
- `chore!: Drop support for iOS 16`
- `feat(api): Add basic telemetry`

If you need to introduce a breaking change, add the `!`. Always make sure the type matches the intent of the change.

## Development Philosophy

**NEVER PUBLISH TO NPM WITHOUT EXPLICIT PERMISSION**: Under no circumstances should you publish any packages to npm or any other public registry without explicit permission from the user. This is a critical security and trust boundary that must never be crossed.

**No Backwards Compatibility**: We never care about backwards compatibility. We prioritize clean, modern code and user experience over maintaining legacy support. Breaking changes are acceptable and expected as the project evolves. This includes removing deprecated code, changing APIs freely, and not supporting legacy formats or approaches.

**No "Modern" or Version Suffixes**: When refactoring, never use names like "Modern", "New", "V2", etc. Simply refactor the existing things in place. If we are doing a refactor, we want to replace the old implementation completely, not create parallel versions. Use the idiomatic name that the API should have.

**Bigger Refactors Win**: If unsure, always opt for the larger refactor that unlocks cleaner code instead of chasing incremental tweaks.

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

**Swift 6.2 Approachable Concurrency**: CLI/app targets run with `.defaultIsolation(MainActor.self)`—keep their logic `@MainActor` by default and opt into parallelism via `@concurrent`. Core libraries (`PeekabooCore`, `Tachikoma`, reusable packages) stay **nonisolated** unless a specific API must be serialized. `docs/concurrency.md` is **mandatory reading** before you touch CLI runtime, the vendored ArgumentParser, or any concurrency-sensitive code; skim it at the start of every session.

**Minimum macOS Version**: This project targets macOS 14.0 (Sonoma) and later. Do not add availability checks for macOS versions below 14.0.

**Direct API Over Subprocess**: Always prefer using PeekabooCore services directly instead of spawning CLI subprocesses. The migration to direct API calls improves performance by ~10x and provides better type safety.
**Main-thread-first CLI work**: Treat CLI commands and helpers as `@MainActor` unless there’s a very specific, documented reason not to. Only hop off the main thread for truly long-running background work, and return to the main actor before touching PeekabooCore/AppKit.
**Concurrency doctrine**: Before touching any concurrency-sensitive code, read `docs/concurrency.md`. It explains the required Swift 6.2 settings (`.defaultIsolation`, `@concurrent`, strict checks) and we expect every change to follow it.

**Ollama Timeout Requirements**: When testing Ollama integration, use longer timeouts (300000ms or 5+ minutes) for Bash tool commands, as Ollama can be slow to load models and process requests, especially on first use.

**Claude Opus 4.1 Availability**: Claude Opus 4.1 (model ID: `claude-opus-4-1-20250805`) is currently available and working. This is not a future model - it exists and functions properly as of August 2025.

**GPT-5 Availability**: GPT-5 (model ID: `gpt-5`) was released on August 7, 2025. `gpt-5-mini` is now the default OpenAI model for Peekaboo agent tasks. The API offers three sizes: `gpt-5` (best for long-form reasoning, 74.9% on SWE-bench), `gpt-5-mini` (cost-optimized default), and `gpt-5-nano` (ultra-low latency). All models support 400K total context (272K input + 128K output tokens).

**GPT-5 Preamble Messages**: When instructed, GPT-5 outputs user-visible preamble messages before and between tool calls to update users on progress during longer agentic tasks. This makes complex operations more transparent by showing the AI's plan and progress at each step.

**GPT-5 Responses API**: GPT-5 uses OpenAI's Responses API (`/v1/responses`) which provides persisted reasoning across tool calls, leading to more coherent and efficient outputs. This API supports `reasoning_effort` (minimal/low/medium/high) and `verbosity` (low/medium/high) parameters for fine-tuned control.

**File Headers**: Use minimal file headers without author attribution or creation dates:
- Swift files: `//\n//  FileName.swift\n//  PeekabooCore\n//` (adapt module name: PeekabooCore, AXorcist, etc.)
- TypeScript files: `//\n//  filename.ts\n//  Peekaboo\n//`
- Omit "Created by" comments and dates to keep headers clean and focused

**No Cross-Reference Comments**: Never add comments like "Note: The 'from' method is now defined in Core/ToolTypes.swift" or similar cross-reference notes. When code is moved or refactored, simply remove it from the old location without leaving explanatory comments. Such comments become outdated quickly and add no value.

To test this project interactive we can use:
`PEEKABOO_AI_PROVIDERS="ollama/llava:latest" npx @modelcontextprotocol/inspector npx -y @steipete/peekaboo-mcp@beta`

## Binary Location and Version Checking

**CRITICAL: Always use `polter peekaboo` to ensure fresh builds!**

1. **Check the build timestamp**: Every Peekaboo execution shows when it was compiled:
   ```
   Peekaboo 3.0.0-beta.1 (main/bdbaf32-dirty, 2025-07-28 17:13:41 +0200)
   ```
   If the timestamp is older than your recent changes, the binary is stale!

2. **Expected binary location**: `/Users/steipete/Projects/Peekaboo/peekaboo` (project root)
   - This is where Poltergeist puts the binary
   - Always use `polter peekaboo` to run it (ensures fresh builds)
   - If you see binaries in other locations, they might be outdated

3. **Verify before testing**:
   ```bash
   # Check version and timestamp
   polter peekaboo --version
   ```

## Quick Reference

```bash
# Core commands
polter peekaboo <command>     # Run CLI with automatic rebuild
./scripts/pblog.sh -f          # Stream logs
npm run poltergeist:status     # Check build status
alias pb='polter peekaboo'    # Add to ~/.zshrc for convenience

# Examples
polter peekaboo agent "take screenshot"
polter peekaboo list apps
polter peekaboo see --annotate

# NEVER use:
# ./peekaboo                   # May run stale binary
# ./scripts/peekaboo-wait.sh   # Redundant wrapper, use polter directly
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

> **Heads up:** `polter peekaboo …` always builds *and launches* the macOS app bundle alongside the CLI binary. There is no headless mode—expect the Peekaboo.app UI to start (and potentially crash) every time you run a Polter command unless you stop the daemon (`npm run poltergeist:stop`) first.

### NEVER
- `polter wait` - doesn't exist
- `npm run build:swift` - Poltergeist does this automatically
- `./peekaboo` - use `polter peekaboo` for fresh builds
- `./scripts/peekaboo-wait.sh` - redundant wrapper, use `polter peekaboo` directly

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
NEVER add cross-reference comments like "Note: X is now defined in Y.swift". When code is moved or refactored, simply remove it without leaving explanatory comments.

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
