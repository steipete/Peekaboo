---
name: peekaboo
description: Use Peekaboo's live CLI and repo workflows for macOS desktop automation: screenshots, UI maps, app/window control, UIAX/action vs synthetic/CAEvent input paths, typing, menus, clipboard, permissions, MCP diagnostics, Inspector parity, and local validation. Use when a task needs current macOS UI state, direct desktop control, or changes to the Peekaboo repo.
allowed-tools: Bash(peekaboo:*), Bash(pkb:*), Bash(pnpm:*), Bash(swift:*), Bash(swiftformat:*), Bash(swiftlint:*), Bash(node scripts/docs-list.mjs:*), Bash(ruby:*), Bash(rg:*)
---

# Peekaboo

Peekaboo is a macOS automation CLI and agent runtime. Prefer the freshly built repo binary and canonical docs over copied command references; command surfaces move fast.

## Start Here

1. In repo work, build/use the local binary:
   ```bash
   pnpm run build:cli
   BIN="$PWD/Apps/CLI/.build/arm64-apple-macosx/debug/peekaboo"
   "$BIN" --version
   ```
2. Confirm permissions before automation:
   ```bash
   peekaboo permissions status
   peekaboo list apps --json
   ```
3. For the latest agent-oriented guide:
   ```bash
   peekaboo learn
   ```
4. For the current tool catalog:
   ```bash
   peekaboo tools
   ```
5. Find command docs:
   ```bash
   node scripts/docs-list.mjs
   ```

## Canonical References

- Live CLI help: `peekaboo <command> --help`
- Full agent guide: `peekaboo learn`
- Tool catalog: `peekaboo tools`
- Command docs in this repo: `docs/commands/README.md` and `docs/commands/*.md`
- Permissions and bridge behavior: `docs/permissions.md`, `docs/bridge-host.md`, `docs/integrations/subprocess.md`
- Repo rules: `AGENTS.md`

## Operating Rules

- Use `peekaboo see --json` before element interactions so you have fresh element IDs and snapshot IDs.
- Prefer element IDs from `see` for clicks and typing; use coordinates only when accessibility metadata is unavailable.
- Check `peekaboo permissions status` before assuming a capture or control failure is a CLI bug.
- Use `--json` when another tool or agent needs to parse results.
- Respect the user's desktop: avoid destructive app/window actions unless requested.
- If a command fails because the target UI changed, recapture with `peekaboo see --json` before retrying.
- For repo fixes, add regression coverage when practical and update `CHANGELOG.md` for user-visible behavior.
- `see --json` element bounds are screen coordinates; snapshot IDs are needed for stable element actions.
- `--no-auto-focus` can prove background behavior, but synthetic clicks may be ignored by some apps until focus is allowed.
- If a saved-snapshot UIAX/action click resolves in the wrong app, inspect snapshot `windowContext` preservation.

## Common Workflows

```bash
# Inspect current UI and save JSON.
peekaboo see --json > /tmp/peekaboo-see.json

# Inspect a target app and extract useful IDs.
peekaboo see --app Calculator --json > /tmp/calc.json
ruby -rjson -e 'j=JSON.parse(File.read("/tmp/calc.json")); puts j.dig("data","snapshot_id"); puts JSON.pretty_generate((j.dig("data","ui_elements")||[]).map{|e| e.slice("id","label","identifier","bounds")})'

# Click an element discovered by see, with snapshot stability.
SNAP=$(ruby -rjson -e 'j=JSON.parse(File.read("/tmp/calc.json")); puts j.dig("data","snapshot_id")')
peekaboo click --on elem_42 --snapshot "$SNAP" --json

# Type into the focused field.
peekaboo type "Hello from Peekaboo"

# Launch/focus an app, then inspect its windows.
peekaboo app launch "Safari"
peekaboo list windows --app Safari --json
```

## Input Path Testing

Peekaboo has two broad input paths:

- UIAX/action path: accessibility actions such as `AXPress`, `AXSetValue`.
- Synthetic path: pointer/keyboard events, commonly the CAEvent/CGEvent-style path.

Useful overrides:

```bash
# Confirm command exposes the override.
peekaboo click --help | rg 'input-strategy|actionOnly|synthOnly'

# UIAX/action click path from a saved snapshot.
peekaboo see --app Calculator --json > /tmp/calc.json
SNAP=$(ruby -rjson -e 'j=JSON.parse(File.read("/tmp/calc.json")); puts j.dig("data","snapshot_id")')
peekaboo click --on elem_8 --snapshot "$SNAP" --input-strategy actionOnly --json --no-auto-focus

# Direct accessibility action; good for proving UIAX independent of pointer events.
peekaboo perform-action --on elem_8 --action AXPress --snapshot "$SNAP" --json

# Synthetic click path; allow focus if you need visible app state to mutate.
peekaboo click --on elem_20 --snapshot "$SNAP" --input-strategy synthOnly --json

# Negative control: coordinates cannot use actionOnly.
peekaboo click --coords 10,10 --input-strategy actionOnly --json --no-auto-focus
```

Interpretation:

- `actionOnly` success proves live AX re-resolution and action invocation.
- `synthOnly` success proves coordinate resolution and event delivery, but verify app state independently.
- `perform-action AXPress` is the cleanest UIAX smoke test.
- Compare with Computer Use or another AX inspector when labels/descriptions differ.

## Calculator Smoke Test

Calculator is a handy fixture because it exposes descriptions and identifiers.

```bash
BIN="$PWD/Apps/CLI/.build/arm64-apple-macosx/debug/peekaboo"
"$BIN" see --app Calculator --json --timeout-seconds 10 > /tmp/calc.json
ruby -rjson -e 'j=JSON.parse(File.read("/tmp/calc.json")); puts JSON.pretty_generate((j.dig("data","ui_elements")||[]).select{|e| ["Clear","AllClear","One","Two","Add","Equals","StandardInputView"].include?(e["identifier"].to_s)}.map{|e| e.slice("id","label","identifier","description","help","bounds")})'

SNAP=$(ruby -rjson -e 'j=JSON.parse(File.read("/tmp/calc.json")); puts j.dig("data","snapshot_id")')
"$BIN" perform-action --on elem_8 --action AXPress --snapshot "$SNAP" --json
"$BIN" click --on elem_19 --snapshot "$SNAP" --input-strategy actionOnly --json --no-auto-focus
"$BIN" click --on elem_20 --snapshot "$SNAP" --input-strategy synthOnly --json
```

Expected current behavior:

- `see --json` includes `bounds` for each `ui_elements` entry.
- Inspector/Computer Use should show Calculator descriptions/IDs such as `One`, `Two`, `StandardInputView`.
- Snapshot-backed UIAX must use the captured app/window, not the frontmost app.

## Repo Validation

```bash
swiftformat <changed-swift-files>
TOOLCHAIN_DIR=/Library/Developer/CommandLineTools swiftlint lint --config .swiftlint.yml <changed-swift-files>
swift build --package-path Apps/CLI
swift build --package-path Core/PeekabooUICore
swift build --package-path Apps/PeekabooInspector
swift test --package-path Apps/CLI --filter <TestName>
swift test --package-path Core/PeekabooAutomationKit --filter <TestName>
```

Notes:

- If tests fail with `no such module 'Testing'`, record it as local toolchain fallout; still run builds/lint/live smoke tests.
- SwiftPM may warn about Commander identity conflicts; do not chase unless the task is dependency hygiene.
- Build via `pnpm run build:cli` for normal CLI work; direct `swift build --package-path ...` is good for focused validation.

Keep this skill compact. Do not vendor generated command references here; update canonical CLI docs or Commander metadata instead.
