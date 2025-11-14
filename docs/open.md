---
summary: 'Spec and implementation plan for the peekaboo open command'
read_when:
  - 'adding or modifying the peekaboo open CLI command'
  - 'routing URLs or documents through default macOS handlers'
---

# peekaboo `open` command specification

## Motivation

Peekaboo currently has parity with `open -a <app>` via `peekaboo app launch`, but we lack the everyday `open <url|path>` workflow that hands a document or URL to the system default handler. Users end up calling out to `/usr/bin/open` through the agent shell tool or automation scripts, which bypasses Peekaboo’s logging, JSON output, focus controls, and error handling. Adding a first-class `open` command closes that gap and gives us a better foundation for document-oriented flows (opening screenshots, PDFs, Finder folders, deep links, etc.).

## UX summary

```
peekaboo open <target> [--app <name-or-path>] [--bundle-id <id>]
                  [--wait-until-ready] [--no-focus] [--json-output]
```

- `<target>`: A URL (`https://`, `file://`, custom schemes) or a local filesystem path. `~` is expanded for paths.
- `--app`: Friendly app name or `.app` path to force a handler (mirrors `open -a`).
- `--bundle-id`: Alternative explicit handler selection.
- `--wait-until-ready`: Poll `NSRunningApplication.isFinishedLaunching` before reporting success (matches `app launch` semantics).
- `--no-focus`: Prevent activation after the target handler launches.
- `--json-output`: Standard CLI-wide behavior.

### Output payload

```json
{
  "success": true,
  "action": "open",
  "target": "<original argument>",
  "resolved_target": "<absolute path or URL>",
  "handler_app": "<app name>",
  "bundle_id": "<bundle identifier>",
  "pid": 12345,
  "is_ready": true,
  "focused": true
}
```

On failure we emit the usual `{ "success": false, "error": { "message": "...", "code": "..." } }`.

## Behavior details

1. **Target resolution**
   - If the argument parses as a URL with a non-empty scheme, treat it as-is.
   - Otherwise expand `~`, resolve relative paths against `FileManager.default.currentDirectoryPath`, and build a file URL (the path does not have to exist; we delegate to `NSWorkspace` for final validation).

2. **Handler selection**
   - When `--bundle-id` is provided, resolve the bundle URL via `NSWorkspace.urlForApplication`.
   - When `--app` is provided, try (in order) bundle lookup, `.app` path, or scanning common application directories (same helper as `app launch`).
   - If neither override is present, let `NSWorkspace` choose the default handler.
   - Invalid selectors throw `NotFoundError.application`.

3. **Execution**
   - Build `NSWorkspace.OpenConfiguration` with `activates = !noFocus`, reuse existing wait/activation helpers from `AppCommand`.
   - Call `NSWorkspace.shared.open(resolvedTarget, configuration:)` and capture the returned `NSRunningApplication`.
   - If `wait-until-ready` is set and the app reports `isFinishedLaunching == false`, poll up to 10s (configurable helper) before timing out with `PeekabooError.timeout`.
   - When `no-focus` is *not* set and activation fails, log a warning but keep success (same as `app launch`).

4. **Result rendering**
   - Print human-readable feedback (`"✅ Opened <target> with <app>"`) or JSON payload described above.

5. **Error handling**
   - Reuse `ErrorHandlingCommand` so validation issues bubble up as structured JSON codes.

## Implementation plan

1. **Command scaffolding**
   - Add `OpenCommand.swift` under `Commands/System/`.
   - Make it conform to `ParsableCommand`, `AsyncRuntimeCommand`, `CommanderBindableCommand`, and `OutputFormattable`.
   - Implement helpers for target/app resolution plus the wait/focus utilities (pull shared code from `AppCommand.LaunchSubcommand` into private extensions where necessary).

2. **Registration**
   - Append `OpenCommand` to `CommandRegistry.entries` in the `.system` category so it appears at the root CLI level and in `peekaboo help`.

3. **Docs**
   - Update `docs/cli-command-reference.md` (or equivalent) once the command lands so the helper surfaces it automatically.

4. **Testing**
   - Add unit coverage under `Apps/CLI/Tests/CoreCLITests` for argument parsing + Commander bindings.
   - Add automation tests (gated behind `RUN_LOCAL_TESTS`) later if we need to validate real UI behavior; basic correctness relies on AppKit and is hard to deterministically simulate in CI.

5. **Follow-up enhancements (not blocking MVP)**
   - Allow multiple targets (`peekaboo open file1 file2`) if demand arises.
   - Support `--background` for parity with `open -g`.
   - Surface errors when the handler returns without actually opening (e.g., misconfigured default apps).

## Testing strategy

- **Unit tests**
  - Commander binding: `peekaboo open https://example.com --bundle-id com.apple.Safari --no-focus --wait-until-ready`.
  - Validation errors: missing target, invalid bundle ID, conflicting selectors.
  - JSON output formatting with mocked `NSWorkspace` (use test doubles similar to `AppCommandTests`).

- **Manual / local automation**
  - `peekaboo open https://example.com --json-output`.
  - `peekaboo open ~/Documents --app "Finder"`.
  - `peekaboo open file:///tmp/foo.txt --no-focus`.
  - `peekaboo open ~/Desktop --bundle-id com.apple.Terminal` (should fail with NotFound).

This spec is the source of truth for implementing the `open` command; keep it updated as behavior evolves.
