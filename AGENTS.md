<shared>
# AGENTS.md

Shared guardrails distilled from the various `~/Projects/*/AGENTS.md` files (state as of **November 15, 2025**). This document highlights the rules that show up again and again; still read the repo-local instructions before making changes.

## Codex Global Instructions
- Keep the system-wide Codex guidance at `~/.codex/AGENTS.md` (the Codex home; override via `CODEX_HOME` if needed) so every task inherits these rules by default.

## General Guardrails

### Intake & Scoping
- Open the local agent instructions plus any `docs:list` summaries at the start of every session. Re-run those helpers whenever you suspect the docs may have changed.
- Review any referenced tmux panes, CI logs, or failing command transcripts so you understand the most recent context before writing code.

### Tooling & Command Wrappers
- Use the command wrappers provided by the workspace (`./runner …`, `scripts/committer`, `pnpm mcp:*`, etc.). Skip them only for trivial read-only shell commands if that’s explicitly allowed.
- Stick to the package manager and runtime mandated by the repo (pnpm-only, bun-only, swift-only, go-only, etc.). Never swap in alternatives without approval.
- When editing shared guardrail scripts (runners, committer helpers, browser tools, etc.), mirror the same change back into the `agent-scripts` folder so the canonical copy stays current.
- Ask the user before adding dependencies, changing build tooling, or altering project-wide configuration.
- Keep the project’s `AGENTS.md` `<tools>
# TOOLS

Edit guidance: keep the actual tool list inside the `<tools></tools>` block below so downstream AGENTS syncs can copy the block contents verbatim (without wrapping twice).

<tools>
- `runner`: Bash shim that routes every command through Bun guardrails (timeouts, git policy, safe deletes).
- `git` / `bin/git`: Git shim that forces git through the guardrails; use `./git --help` to inspect.
- `scripts/committer`: Stages the files you list and creates the commit safely.
- `scripts/docs-list.ts`: Walks `docs/`, enforces front-matter, prints summaries; run `tsx scripts/docs-list.ts`.
- `scripts/browser-tools.ts`: Chrome helper for remote control/screenshot/eval; run `ts-node scripts/browser-tools.ts --help`.
- `scripts/runner.ts`: Bun implementation backing `runner`; run `bun scripts/runner.ts --help`.
- `bin/sleep`: Sleep shim that enforces the 30s ceiling; run `bin/sleep --help`.
- `xcp`: Xcode project/workspace helper; run `xcp --help`.
- `oracle`: CLI to bundle prompt + files for another AI; run `npx -y @steipete/oracle --help`.
- `mcporter`: MCP launcher for any registered MCP server; run `npx mcporter`.
- `iterm`: Full TTY terminal via MCP; run `npx mcporter iterm`.
- `firecrawl`: MCP-powered site fetcher to Markdown; run `npx mcporter firecrawl`.
- `XcodeBuildMCP`: MCP wrapper around Xcode tooling; run `npx mcporter XcodeBuildMCP`.
- `gh`: GitHub CLI for PRs, CI logs, releases, repo queries; run `gh help`.
</tools>

</tools>
` block in sync with the full tool list from `TOOLS.md` so downstream repos get the latest tool descriptions.

### tmux & Long Tasks
- Run any command that could hang (tests, servers, log streams, browser automation) inside tmux using the repository’s preferred entry point.
- Do not wrap tmux commands in infinite polling loops. Run the job, sleep briefly (≤30 s), capture output, and surface status at least once per minute.
- Document which sessions you create and clean them up when they are no longer needed unless the workflow explicitly calls for persistent watchers.

### Build, Test & Verification
- Before handing off work, run the full “green gate” for that repo (lint, type-check, tests, doc scripts, etc.). Follow the same command set humans run—no ad-hoc shortcuts.
- Leave existing watchers running unless the owner tells you to stop them; keep their tmux panes healthy if you started them.
- Treat every bug fix as a chance to add or extend automated tests that prove the behavior.

### Code Quality & Naming
- Refactor in place. Never create duplicate files with suffixes such as “V2”, “New”, or “Fixed”; update the canonical file and remove obsolete paths entirely.
- Favor strict typing: avoid `any`, untyped dictionaries, or generic type erasure unless absolutely required. Prefer concrete structs/enums and mark public concurrency surfaces appropriately.
- Keep files at a manageable size. When a file grows unwieldy, extract helpers or new modules instead of letting it bloat.
- Match the repo’s established style (commit conventions, formatting tools, component patterns, etc.) by studying existing code before introducing new patterns.

### Git, Commits & Releases
- Invoke git through the provided wrappers, especially for status, diffs, and commits. Only commit or push when the user asks you to do so.
- Follow the documented release or deployment checklists instead of inventing new steps.
- Do not delete or rename unfamiliar files without double-checking with the user or the repo instructions.

### Documentation & Knowledge Capture
- Update existing docs whenever your change affects them, including front-matter metadata if the repo’s `docs:list` tooling depends on it.
- Only create new documentation when the user or local instructions explicitly request it; otherwise, edit the canonical file in place.
- When you uncover a reproducible tooling or CI issue, record the repro steps and workaround in the designated troubleshooting doc for that repo.

### Troubleshooting & Observability
- Design workflows so they are observable without constant babysitting: use tmux panes, CI logs, log-tail scripts, MCP/browser helpers, and similar tooling to surface progress.
- If you get stuck, consult external references (web search, official docs, Stack Overflow, etc.) before escalating, and record any insights you find for the next agent.
- Keep any polling or progress loops bounded to protect hang detectors and make it obvious when something stalls.

### Stack-Specific Reminders
- Start background builders or watchers using the automation provided by the repo (daemon scripts, tmux-based dev servers, etc.) instead of running binaries directly.
- Use the official CLI wrappers for browser automation, screenshotting, or MCP interactions rather than crafting new ad-hoc scripts.
- Respect each workspace’s testing cadence (e.g., always running the main `check` script after edits, never launching forbidden dev servers, keeping replies concise when requested).

## Swift Projects
- Kick off the workspace’s build daemon or helper before running any Swift CLI or app; rely on the provided wrapper to rebuild targets automatically instead of launching stale binaries.
- Validate changes with `swift build` and the relevant filtered test suites, documenting any compiler crashes and rewriting problematic constructs immediately so the suite can keep running.
- Keep concurrency annotations (`Sendable`, actors, structured tasks) accurate and prefer static imports over dynamic runtime lookups that break ahead-of-time compilation.
- Avoid editing derived artifacts or generated bundles directly—adjust the sources and let the build pipeline regenerate outputs.
- When encountering toolchain instability, capture the repro steps in the designated troubleshooting doc and note any required cache cleans (DerivedData, SwiftPM caches) you perform.

## TypeScript Projects
- Use the package manager declared by the workspace (often `pnpm` or `bun`) and run every command through the same wrapper humans use; do not substitute `npm`/`yarn` or bypass the runner.
- Start each session by running the repo’s doc-index script (commonly a `docs:list` helper), then keep required watchers (`lint:watch`, `test:watch`, dev servers) running inside tmux unless told otherwise.
- Treat `lint`, `typecheck`, and `test` commands (e.g., `pnpm run check`, `bun run typecheck`) as mandatory gates before handing off work; surface any failures with their exact command output.
- Maintain strict typing—avoid `any`, prefer utility helpers already provided by the repo, and keep shared guardrail scripts (runner, committer, browser helpers) consistent by syncing back to `agent-scripts` when they change.
- When editing UI code, follow the established component patterns (Tailwind via helper utilities, TanStack Query for data flow, etc.) and keep files under the preferred size limit by extracting helpers proactively.

Keep this master file up to date as you notice new rules that recur across repositories, and reflect those updates back into every workspace’s local guardrail documents.

</shared>

<tools>
# TOOLS

Edit guidance: keep the actual tool list inside the `<tools></tools>` block below so downstream AGENTS syncs can copy the block contents verbatim (without wrapping twice).

<tools>
- `runner`: Bash shim that routes every command through Bun guardrails (timeouts, git policy, safe deletes).
- `git` / `bin/git`: Git shim that forces git through the guardrails; use `./git --help` to inspect.
- `scripts/committer`: Stages the files you list and creates the commit safely.
- `scripts/docs-list.ts`: Walks `docs/`, enforces front-matter, prints summaries; run `tsx scripts/docs-list.ts`.
- `scripts/browser-tools.ts`: Chrome helper for remote control/screenshot/eval; run `ts-node scripts/browser-tools.ts --help`.
- `scripts/runner.ts`: Bun implementation backing `runner`; run `bun scripts/runner.ts --help`.
- `bin/sleep`: Sleep shim that enforces the 30s ceiling; run `bin/sleep --help`.
- `xcp`: Xcode project/workspace helper; run `xcp --help`.
- `oracle`: CLI to bundle prompt + files for another AI; run `npx -y @steipete/oracle --help`.
- `mcporter`: MCP launcher for any registered MCP server; run `npx mcporter`.
- `iterm`: Full TTY terminal via MCP; run `npx mcporter iterm`.
- `firecrawl`: MCP-powered site fetcher to Markdown; run `npx mcporter firecrawl`.
- `XcodeBuildMCP`: MCP wrapper around Xcode tooling; run `npx mcporter XcodeBuildMCP`.
- `gh`: GitHub CLI for PRs, CI logs, releases, repo queries; run `gh help`.
</tools>

</tools>

# AGENTS.md


This file provides guidance to our automation agents (Claude Code, GPT-5, and friends) when working with code in this repository.

## Project Status (November 5, 2025)

- **Dependency refresh**: local `Commander` package (replaces swift-argument-parser), `swift-async-algorithms 1.0.4`, `swift-collections 1.3.0`, `swift-crypto 3.15.1`, `swift-system 1.6.3`, plus `swift-sdk 0.10.2` (official MCP release) across PeekabooCore/Tachikoma/Apps.
- **SwiftPM manifest order**: `Package(...)` now includes `swiftLanguageModes`, which *must* trail the `targets` argument (initializer label order: `name, defaultLocalization, platforms, pkgConfig, providers, products, dependencies, targets, swiftLanguageModes, cLanguageStandard, cxxLanguageStandard`). If SwiftPM yells about “argument 'dependencies' must precede argument 'swiftLanguageModes'”, move the `swiftLanguageModes` block to the very end of the initializer. Verified via `pnpm oracle -- --engine browser --slug ci-complains-argument-targets-must-2` referencing Apple’s PackageDescription docs for Swift 6.2.
- **Code updates**: centralized `LanguageModel.parse` in Tachikoma, replaced ad-hoc agent glyphs with `AgentDisplayTokens`, removed TermKit TUI hooks from CLI, default agent model now `gpt-5.1`, emojis toned down in agent output, and Mac icon assets/resources registered for SwiftPM.
- **Verification**: `swift build` clean for Tachikoma, PeekabooCore, peekaboo CLI, and macOS app; `swift test --filter TypeCommandTests` currently hits a Swift frontend signal 5 (compiler bug) even outside tmux—log captured for follow-up. Other large suites remain gated by `RUN_LOCAL_TESTS=true`.
- **Crash workarounds tracking**: When SILGen (or related compiler pieces) explode—especially around key-path sugar—document the repro + workaround steps in `docs/silgen-crash-debug.md` and rewrite the offending code/tests immediately instead of waiting for Apple to ship a fixed toolchain.
- **SILGen key-path landmines**: Swift 6.2 still crashes in SILGen when tests lean on key-path maps (see `docs/silgen-crash-debug.md`). Avoid `array.map(\\.foo)` and similar sugar inside automation tests; rewrite them as for-in loops before filing new bugs.
- **Compiler workarounds required**: We can’t wait for Apple to ship a fixed Swift compiler. When SILGen (or related) crashes block progress, isolate the offending construct and rewrite it into an equivalent shape that dodges the bug; document the workaround in `docs/silgen-crash-debug.md` so other agents reuse it instead of blocking on upstream fixes.
- **Next steps**: file Swift compiler crash with stack dump, add test subsets so automation suites compile in smaller batches, and revisit `tmux`-logged test strategy once the compiler issue is resolved.
- **CI note**: when running long Swift test suites use bare `tmux new-session …` invocations (no `while` loops or `tmux wait-for` wrappers). Continuous polling prevents our hang detector from spotting stuck jobs, which defeats the reason we run tests inside tmux. When implementing progress checks or back-off behaviour, cap individual `sleep`/timeout intervals at **≤30s** so the hang detector retains sufficient cadence.
- **CI monitoring**: use the GitHub CLI to inspect jobs instead of guessing. Examples: `gh run list --workflow "macOS CI" --limit 5` to see recent runs and `gh run view <run-id> --log` (or `--job <job-id> --log`) to stream detailed logs when a step fails.
- **Package manager**: we use `pnpm` for every JS/TS script or dependency install. Never call `npm install`, `npm run`, or `yarn` inside this repo—replace those with the equivalent `pnpm` command (e.g., `pnpm run poltergeist:haunt`).
- **tmux usage**: Avoid `while tmux …` polling or `tmux wait-for`; prefer direct `tmux` commands with occasional bounded `sleep` calls, and investigate any `tmux`-run command that approaches 10 minutes rather than letting it run unattended.
- **Note**: tmux here does allocate a real TTY; use it via `./runner tmux …` when you need isolation, but avoid nesting runners.
- **codex in tmux**: `codex` works under tmux (`codex-cli 0.55.0`). Detached runs exit as soon as output finishes, which tears down the session; attach immediately (`./runner tmux attach -t codex`) or keep the pane alive with a short `read -t` when you need to interact.
- **Log streaming**: Any `log stream`, `log show --style live`, or similar tail that can run longer than a few seconds **must** run inside tmux via the runner (e.g., `./runner tmux new-session -- log stream …`). Running those directly will hang the harness and crash your session.
- **Runner vs tmux**: Use the runner *or* tmux for a command, not both. If the task requires tmux, invoke `tmux` directly with the runner’s `./runner tmux …` wrapper; don’t nest additional runner layers inside the tmux command.
- **Loops & polling**: Never write open-ended `while` loops (especially in test scripts) that can block indefinitely. Always bound the iteration count or timeout (e.g., break after N checks) so hung processes can’t stall the agent forever, and when polling tmux/test status pick a sleep interval ≤30s so the hang detector still gets signal. \
  **New rule:** Any loop that waits on tool/test completion must cap its total wait time at **≤60s** before surfacing progress. Use tmux plus short `sleep` bursts (e.g., spawn the job with `tmux new-session …` and poll with `sleep 5` / `sleep 10` up to a minute) rather than camping in one `while` forever. After 60 seconds, print/log status, re-evaluate, or exit—never leave a background loop unattended.
- **Docs intake**: Kick off each session with `pnpm run docs:list` (wrapper around `scripts/docs-list.mjs`). It prints every doc + its summary metadata and flags the ones missing front matter. Open every doc relevant to your task, keep it nearby while implementing, and immediately add/update the front matter block (`---`, `summary: '...'`, `read_when:`) for any doc you edit so the helper keeps surfacing accurate guidance.
- **Research rule**: Whenever you're stuck or even slightly unsure about an approach, run a quick web search (e.g., `web.run` via Google) before guessing—cite what you find and keep iterating until you have a grounded plan.
- **When stuck**: If you’re unsure how to proceed, temporarily pause and look for external references—run a quick web search (Google, Stack Overflow, Apple docs, etc.) for similar symptoms before escalating. Capture anything relevant back in the issue/notes so the next agent has context.
- **Agent model choice**: When validating agentic flows end-to-end, prefer OpenAI GPT-5 or Anthropic Claude Sonnet 4.5—those two models currently give the most reliable Peekaboo behavior and should be the baseline for deep debugging. Other Tachikoma models remain allowed (and are great for smoke tests or repro attempts), so keep overrides flexible when writing tooling; just default your own test passes to GPT-5/Sonnet 4.5 unless there’s a specific reason to cover another provider.
- **Swift key-path map crashes**: Swift 6.2 still has SILGen bugs triggered by `array.map(\.foo)` patterns inside the automation tests. When touching those suites, prefer explicit loops, and see `docs/silgen-crash-debug.md` for the history and the list of files we already refactored to work around signal-5 compiler crashes.
- **Commit discipline**: Batch related changes before committing. Never commit single files opportunistically—coordinate commit groups so parallel agents aren’t surprised by partially landed work.
- **Committer script**: All commits must go through `./scripts/committer "type(scope): subject" "path/to/file1" "path/to/file2"`. Pass the commit message as the first quoted argument, list every file path after it (also quoted), and let the helper manage staging—never run `git add` manually. The script validates paths, clears the index, re-stages only the listed files, and then creates the commit so you can land exactly what you expect.
- **Version control hygiene**: Never revert or overwrite files you did not edit. Other agents and humans may be working in parallel, so avoid destructive operations (including `git checkout`, `git reset`, or similar) unless explicitly instructed.
- **Git via runner**: The only git commands you may run are `status`, `diff`, `log`, and (when explicitly requested) `push`, and every one of them must go through the wrapper (`./runner git status -sb`, etc.). If the user types a guarded subcommand like “rebase,” include `RUNNER_THE_USER_GAVE_ME_CONSENT=1` in the same command before invoking `./runner git rebase …`. Destructive git operations remain forbidden without written approval in this thread.
- **Subrepo git access (Nov 14, 2025)**: All top-level submodules (`/AXorcist`, `/Commander`, `/Tachikoma`, `/TauTUI`) have their own `.git`. You may run native `git add/commit/push` inside any of these subrepositories when needed, since `./scripts/committer` only targets the root repo. Continue using `./runner git …` for the main Peekaboo tree unless the user explicitly instructs otherwise.
- **Submodule layout**: We now have four first-class git submodules rooted at the repo top level: `/AXorcist`, `/Commander`, `/Tachikoma`, and `/TauTUI`. Treat each as source of truth for those shared packages; never copy files back under `Core/`.
- **Custom dependency forks**: Commander now lives in `/Commander` and is shared across every package. Don’t reintroduce swift-argument-parser—the old fork is gone.
- **Submodule safety**: Peter edits `Tachikoma/` directly. Never run destructive git commands (`git checkout -- .`, `git reset --hard`, etc.) inside Tachikoma without his explicit approval.
- **Runner awareness**: Any task that regularly runs longer than ~1 minute (heavy builds, lint, long tests) must use the extended runner window—update the runner keyword list whenever a new long job appears so CI doesn’t evict your work.
- **Runner wrapper**: Run every build, test, package script, tmux-managed command, and git invocation through `./runner <command>` so the guardrails enforce timeouts and git policies. Only lightweight read-only utilities (`rg`, `sed`, `ls`, `cat`, etc.) may bypass it. Pass script flags after `--` (e.g., `./runner pnpm test -- --run`) and pay attention when the wrapper asks you to move multi-minute work into tmux.
- **PeekabooServices installation**: Any code (apps, tests, tools, harnesses) that instantiates `PeekabooServices()` must immediately call `services.installAgentRuntimeDefaults()` before touching `ToolRegistry`, `MCPToolContext`, or `PeekabooAgentService`. This registers the container as the process-wide default so MCP tools and CLI runtimes share the same services. The CLI `CommandRuntime` and Peekaboo macOS app already do this; if you spin up services elsewhere (integration tests, playgrounds, custom daemons) you must do the same or the MCP/ToolRegistry calls will crash.
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

**GPT-5.1 Availability**: GPT-5.1 (model ID: `gpt-5.1`) shipped on November 14, 2025 with upgraded reasoning + tool use. `gpt-5.1` is the default OpenAI model for Peekaboo agent tasks, with `gpt-5.1-mini` and `gpt-5.1-nano` available as lower-cost and ultra-low-latency variants. All three share the 400K total context window (272K input + 128K output). The GPT-5 family remains available for compatibility but is no longer the default.

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
pnpm oracle                   # Smart Oracle CLI quick help (proxies to pnpm -C ../oracle oracle)

# Examples
polter peekaboo agent "take screenshot"
polter peekaboo list apps
polter peekaboo see --annotate

# NEVER use:
# ./peekaboo                   # May run stale binary
# ./scripts/peekaboo-wait.sh   # Redundant wrapper, use polter directly
```

Oracle is a CLI to get help from a very smart AI. `pnpm oracle` now shells into the neighboring repo (`pnpm -C ../oracle oracle`), so each invocation builds the TypeScript sources before running the CLI—no more stale `dist`. If that repo breaks, fix it there first.

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
