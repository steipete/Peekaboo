---
summary: 'Track active interaction-layer bugs and reproduction steps'
read_when:
  - Debugging CLI interaction regressions
  - Triaging Peekaboo automation failures
---

# Interaction Debugging Notes

> **Mission Reminder (Nov 12, 2025):** The mandate for this doc is to *continuously* exercise every Peekaboo CLI feature until automation covers everything a human can do on macOS. That means:
> - Systematically try every command/subcommand/flag combination (see/see, menu, dialog, window, list, type, drag, press, etc.) and capture regressions here.
> - Treat each bug as blocking mission readiness—fix it or write down why it’s pending.
> - Assume future user prompts can request any macOS action; keep tightening Peekaboo until every tool path (focus, screenshot, menu, dialog, shell, automation) is battle‑tested.
> - When in doubt, reopen TextEdit or another stock app, try to automate the workflow end-to-end via Peekaboo, and log the outcome below.

## `see` command can’t finalize captures
- **Command**: `polter peekaboo -- see --app TextEdit --path /tmp/textedit-see.png --annotate --json-output`
- **Observed**: Logger reports a successful capture, saves `/tmp/textedit-see.png`, then throws `INTERNAL_SWIFT_ERROR` with message `The file “textedit-see.png” doesn’t exist.` The file *does* exist immediately after the failure (checked via `ls -l /tmp/textedit-see.png`).
- **Expected**: Command should return success (or at least surface a real capture error) once the screenshot is on disk.
- **Impact**: Blocks every downstream workflow that needs fresh UI element maps. Even `peekaboo see --app TextEdit` without `--path` fails with the same error, so agents can’t gather element IDs at all.
### Investigation log — Nov 11, 2025
- Replayed the capture pipeline inside `SeeCommand`: `saveScreenshot` writes to the requested path, after which we call `SessionManager.storeScreenshot` before any other session persistence occurs.
- Traced `SessionManager.storeScreenshot` and found it copied the file into `.peekaboo/session/<id>/raw.png` without ensuring the destination directory existed. The resulting `FileManager.copyItem` threw `NSCocoaErrorDomain Code=4 "The file “textedit-see.png” doesn’t exist."`, bubbling up as `INTERNAL_SWIFT_ERROR`.
### Resolution — Nov 12, 2025
- `SessionManager.storeScreenshot` now creates the per-session directory before copying, standardizes the source URL, and reports a clearer file I/O error if the user-provided path truly disappears. `peekaboo see --path /tmp/foo.png --annotate --json-output` completes successfully and downstream element/session storage works again.

## AXorcist logging broke every CLI build
- **Command**: `polter peekaboo -- type "Hello"` (or any other subcommand)
- **Observed**: Poltergeist failed the build instantly with `cannot convert value of type 'String' to expected argument type 'Logger.Message'` coming from `ElementSearch`/`AXObserverCenter`. Even a bare `./runner swift build --package-path Apps/CLI` tripped on the same diagnostics, so no CLI binary could launch.
- **Expected**: Logger helper strings should compile cleanly; CLI builds should succeed without `--force`.
- **Impact**: All automation flows regressed—`polter peekaboo …` crashed before executing, preventing us from driving TextEdit or debugging dialog flows.
### Resolution — Nov 12, 2025
- Added a `Logging.Logger` convenience shim in `Core/AXorcist/Sources/AXorcist/Logging/GlobalAXLogger.swift` so dynamic `String` messages are emitted as proper `Logger.Message` values.
- Updated `ElementSearch` logging helpers (`logSegments([String])`) and the `SearchVisitor` initializer to avoid illegal variadic splats and `let` reassignments.
- Fixed `AXObserverCenter`’s observer callback to call `center.logSegments/describePid` explicitly, preventing implicit `self` captures.
- Verified the end-to-end fix by running `./runner swift build --package-path Apps/CLI` and `./runner polter peekaboo -- type "Hello from CLI" --app TextEdit --json-output`, both of which now succeed without `--force`.

## Agent `--model` flag lost its parser
- **Command**: `./runner swift test --package-path Apps/CLI --filter DialogCommandTests`
- **Observed**: Build failed with `value of type 'AgentCommand' has no member 'parseModelString'` because the helper that normalizes model aliases was deleted. That broke the CLI tests and meant `peekaboo agent --model ...` no longer validated user input.
- **Expected**: Human-facing aliases like `gpt`, `gpt-4o`, or `claude-sonnet-4.5` should downcase to the supported defaults (`gpt-5` or `claude-sonnet-4.5`) so both tests and the runtime can enforce safe model choices.
### Resolution — Nov 12, 2025
- Reintroduced `AgentCommand.parseModelString(_:)`, delegating to `LanguageModel.parse` and whitelisting the GPT-5/Claude 4.5 families. GPT variants (gpt/gpt-5-mini/gpt-4o) now map to `.openai(.gpt5)`, Claude variants (opus/sonnet 4.x) map to `.anthropic(.sonnet45)`, and unsupported providers still return `nil`.
- `./runner swift test --package-path Apps/CLI --filter DialogCommandTests` now builds again (the filter currently matches zero tests, but the previous compiler failure is gone), and the helper is ready for the rest of the CLI to consume when we re-enable the `--model` flag.

## `list windows` silently emits nothing
- **Command**: `polter peekaboo list windows --app TextEdit`
- **Observed**: Exit status 0 but no stdout/stderr, regardless of `--json-output` or `--verbose`.
- **Expected**: Either a formatted window list or an explicit “no windows found” message / JSON payload.
- **Impact**: Prevents automation flows from enumerating windows to obtain IDs; also makes debugging focus issues impossible because there’s no feedback.
### Investigation log — Nov 11, 2025
- `ListCommand.WindowsSubcommand` always calls `print(CLIFormatter.format(output))`, so the lack of output meant the formatter returned an empty string.
- `CLIFormatter.formatWindowList` explicitly returned `""` whenever the windows array was empty, wiping both the one-line summary and any hints/warnings, so the CLI rendered nothing.
### Resolution — Nov 12, 2025
- `CLIFormatter` now emits `⚠️ No windows found for <app>` when the window array is empty and adds a generic “No output available” fallback if every section is blank. The JSON path was already correct, so no change needed there.

## Window geometry commands report stale dimensions
- **Commands**:
  - `polter peekaboo window set-bounds --app TextEdit --window-title "Untitled 5.rtf" --x 100 --y 100 --width 600 --height 500 --json-output`
  - `polter peekaboo window resize --app TextEdit --window-title "Untitled 5.rtf" --width 700 --height 550 --json-output`
- **Observed**: Each command visibly moves/resizes the window, but the JSON payload’s `new_bounds` echoes the *previous* invocation. Example: after `set-bounds` to `(100,100,600,500)`, running again with `--x 400 --y 400 --width 800 --height 600` still reports `{x:100,y:100,width:600,height:500}` even though the window now sits at `(400,400,800,600)`. Likewise, `window resize` reported the rectangle applied by the prior `set-bounds` call instead of the requested 700×550 region.
- **Expected**: `new_bounds` should match the rectangle we just applied for both commands.
- **Impact**: Automation scripts can’t trust the CLI output to confirm state; retries or verification steps will mis-report success.
### Next steps
1. Inspect `WindowCommand.SetBoundsSubcommand` and `WindowCommand.ResizeSubcommand` (or the shared window service) so success responses include the freshly applied bounds instead of cached state.
2. Add CLI regression tests asserting `new_bounds` equals the requested rectangle for both `set-bounds` and `resize`.

## `menu list` fails with "Could not find accessibility element for window ID"
- **Command**: `polter peekaboo menu list --app TextEdit --json-output`
- **Observed**: After exercising other window commands (focus/move/set-bounds), `menu list` now crashes with `UNKNOWN_ERROR` and `Could not find accessibility element for window ID 798`. Re-focusing the TextEdit window doesn’t help; every `menu list` attempt errors with the same stale window ID even though the app is frontmost.
- **Expected**: Menu enumeration should succeed once the window (or app) is focused.
- **Impact**: Menu automation is unusable in long sessions—agents can’t inspect menus after other window operations because the CLI clings to a dead AX window reference.
### Next steps
1. Investigate `MenuCommand` / `MenuService` to ensure they refresh the AX window reference each invocation instead of reusing stale IDs.
2. Add a stress test: run `window move`/`focus`/`list` repeatedly and ensure a subsequent `menu list` still works.

## `menu click` fails with same stale window ID
- **Command**: `polter peekaboo menu click --app TextEdit --path File,New --json-output`
- **Observed**: Immediately after the `menu list` failure above, `menu click` also returns `UNKNOWN_ERROR` with `Could not find accessibility element for window ID 798`. Opening a new TextEdit document (to spawn a fresh window ID) simply changes the failing ID to `838`, confirming the CLI is caching dead AX handles between calls.
- **Expected**: `menu click` should re-resolve the window each time.
- **Impact**: No menu automation works once the cached window ID drifts.
### Next steps
Same as above—refresh AX window references inside `MenuCommand` and add regression coverage for both list & click paths.

## `menu click` still fails with NotFound after window refresh
- **Command**: `polter peekaboo menu click --app TextEdit --path File,New --json-output`
- **Observed**: After restarting TextEdit and getting `menu list` working again, `menu click` now fails with `PeekabooCore.NotFoundError` (no stale window ID, but menu path resolution still breaks). Even `TextEdit,Preferences` fails with the same code.
- **Expected**: Menu paths should resolve when `menu list` succeeds.
- **Impact**: Click automation can’t drive menus even when enumeration works.
### Next steps
Investigate `MenuService.clickMenuPath` once `menu list` is fixed; ensure both stack traces share the same AX lookup logic.

## `menu click` fails in Calculator too
- **Command**: `polter peekaboo menu click --app Calculator --path View,Scientific --json-output`
- **Observed**: Even after a fresh `menu list` succeeds, clicking `View > Scientific` fails with `PeekabooCore.NotFoundError error 1.` The issue isn’t TextEdit-specific—Calculator shows the same behavior.
- **Impact**: Menu automation is effectively unusable across apps.
- **Next steps**: Once the stale-window-id issue is fixed, verify the click path is resolving menu nodes correctly (and add integration coverage for at least one stock app such as Calculator).

## Help surface is unreachable
- Root help instructs users to run `peekaboo help <subcommand>` or `<subcommand> --help`, but:
  - `polter peekaboo help window` → `Error: Unknown command 'help'`
  - `polter peekaboo image --help` → `Error: Unknown option --help`
  - Even `polter peekaboo click --help` gets intercepted by `polter`’s own help instead of reaching Peekaboo.
- **Impact**: There is no discoverable way to read per-command usage/flags from the CLI, which leaves agents guessing (and documentation contradicting reality).
### Investigation log — Nov 11, 2025
- Commander only injected verbose/json/log-level flags; `help` wasn’t registered as a command and `--help`/`-h` were treated as unknown options, so the router rejected every attempt before `CommandHelpRenderer` could run.
### Resolution — Nov 12, 2025
- `CommanderRuntimeRouter` now strips the executable name, intercepts `help`, `--help`, and `-h` tokens, renders help for the requested path (or prints a root command table), and exits with `ExitCode.success`. Users can once again discover per-command signatures straight from the CLI.

### Next steps I'd suggest
1. Add regression tests for `SessionManager.storeScreenshot` that cover relative paths, missing directories, and annotated captures so the copy guardrails stay in place.
2. Backfill CLI integration coverage for `peekaboo list windows` (text + JSON) to guarantee the warning footer appears when no windows are detected.
3. Extend `CommandHelpRenderer` output (and docs) with richer examples/subcommand tables so the new help plumbing doubles as user-facing reference material.

## `menu list` produces no output at all
- **Command**: `polter peekaboo menu list --app Finder --json-output`
- **Observed**: Command exits 0 but emits zero bytes (even when piping to a file). Adding `-v` prints a stray `1.7.3` and still no JSON/text.
- **Impact**: The entire menu-inspection surface is unusable—agents can’t enumerate menus to click, and scripts can’t consume JSON.
- **Hypothesis**: We successfully focus Finder and retrieve the AX menu structure, but `outputSuccessCodable` never fires because `MenuServiceBridge.listMenus` probably hits a runtime-only type that can’t be converted, short-circuiting before printing. Need to instrument `ListSubcommand` to confirm and add tests that assert JSON is printed.
### Additional findings — Nov 12, 2025
- `menu click` behaves the same (totally silent, exit 0). Because both subcommands share the same runtime plumbing, it’s likely that the Commander binder never injects runtime options into `MenuCommand` (so stdout is being swallowed or the program returns before printing). Since `menu list-all` does output correctly, the bug is isolated to `ListSubcommand`/`ClickSubcommand`.
- **Resolution — Nov 12, 2025**: `ApplicationResolvablePositional` used to override `var app` with `var app: String? { app }`, which immediately recursed and crashed every positional command (menu/app/window, etc.). The protocol now exposes a separate `positionalAppIdentifier` and the subcommands map their `app` argument to it, so the commands run normally (and emit JSON errors when Finder has no visible window instead of segfaulting).
- **Remaining gap**: Even with the crash fixed, `menu list --app Finder` still fails with “No windows found” whenever Finder has only the menubar showing. We should allow menu enumeration without a target window (Finder’s menus exist even if no browser windows are open).

## `menubar list` returns placeholder names
- **Command**: `polter peekaboo menubar list --json-output`
- **Observed**: Visible status items like Wi‑Fi or Focus are present, but most entries show `title: "Item-0"` / `description: "Item-0"`, which is meaningless.
- **Impact**: Agents can’t rely on human-friendly titles to choose items, so they can’t click menu extras deterministically.
- **Suggestion**: Surface either the accessibility label or the NSStatusItem’s button title instead of the placeholder, and include bundle identifiers for menu extras where possible.

## `window focus` reports INTERNAL_SWIFT_ERROR instead of WINDOW_NOT_FOUND
- **Command**: `polter peekaboo window focus --app Finder --json-output`
- **Observed**: When Finder’s dock tile has no “real” AX window, the command returns `{ code: "INTERNAL_SWIFT_ERROR", message: "Could not find accessibility element for window ID 91" }`.
- **Expected**: It should surface a structured `.WINDOW_NOT_FOUND` error (matching the rest of the CLI) so agents can fall back to `window list` or `app focus`.
- **Impact**: Automations have to pattern-match brittle strings to detect “window missing” vs. actual internal failures.

## `agent --list-sessions` used to crash due to eager MCP init
- **Command**: `polter peekaboo agent --list-sessions --json-output`
- **Observed (before fix)**: Launching the CLI triggered the Peekaboo SwiftUI app to start, which then broke inside `NSHostingView` layout (SIGTRAP). The root cause was that we bootstrapped Tachikoma MCP (spawning the GUI) even when the user only wanted metadata.
- **Resolution — Nov 12, 2025**: The CLI now handles `--list-sessions` before touching MCP/logging setup, so it queries the agent service without launching the app or requiring credentials. Repeat runs return JSON instantly.

## `clean --dry-run` returned INTERNAL_SWIFT_ERROR on validation failure
- **Command**: `polter peekaboo clean --dry-run --json-output`
- **Observed**: Leaving out `--all-sessions/--session/--older-than` produced `{ "success": false, "code": "INTERNAL_SWIFT_ERROR" }` even though it’s a user mistake.
- **Resolution — Nov 12, 2025**: CleanCommand now throws `ValidationError` and emits `VALIDATION_ERROR` in JSON (matching the CLI guidelines). Added regression tests would still be useful.

## `menu list` fails when the target app only provides a menubar
- **Command**: `polter peekaboo menu list --app Finder --json-output`
- **Observed**: Command exited with `UNKNOWN_ERROR` and message `No windows found for application 'Finder'`, even though Finder’s menus are accessible through the menubar.
- **Expected**: Menu enumeration should succeed whenever an application exposes a menu bar, regardless of whether it has an open document window.
- **Impact**: Finder and similar background apps remain unreachable by `peekaboo menu`, leaving menu automation helpless for those targets.
### Investigation log — Nov 12, 2025
- `MenuCommand` called `ensureFocused` with the default focus options, which in turn invoked `FocusManagementService.findBestWindow`. Finder’s menubar-only state triggered `FocusError.noWindowsFound`, so the command threw before reaching `MenuServiceBridge.listMenus`.
- The helper was always configured with auto-focus enabled, so every menu subcommand ran the same path.
### Resolution — Nov 12, 2025
- Added `ensureFocusIgnoringMissingWindows` in `MenuCommand` so menu operations log and skip focus when `FocusError.noWindowsFound` occurs.
- `menu list`/`menu click` now work for Finder even when no document windows exist; the command output continues once the focus guard silently falls through.

## `menubar list` shows generic titles like Item-0 instead of real labels
- **Command**: `polter peekaboo menubar list`
- **Observed**: Most entries had `title: "Item-0"` (and similar placeholders) even though the corresponding icons have descriptive accessibility labels.
- **Expected**: Use the accessibility tree title/help strings so the JSON/text output names items properly (e.g., Wi-Fi, Control Center, Bluetooth).
- **Impact**: Agents cannot target status items reliably because the CLI output never exposes their real names.
### Investigation log — Nov 12, 2025
- `MenuService.listMenuExtras` appended the window-based heuristics first, then only added accessibility-discovered extras if their positions didn’t collide. The heuristic window entries had `AXWindowOwnerName` values such as `Item-0`, so those entries dominated the JSON output.
- We needed a deterministic, testable merge strategy rather than relying on whichever source ran first.
- Ice’s menu manager taught us to pair bundle IDs with names when labeling extras, so we could swap the fallback data for accessibility strings like “Wi-Fi”, “Focus”, and “Control Center” when they share a position.
### Resolution — Nov 12, 2025
- Reordered `listMenuExtras` to prioritize accessible extras and introduced `MenuService.mergeMenuExtras` to deduplicate by position before appending fallback windows.
- Added `MenuServiceTests` to verify the merge logic keeps accessibility titles (Wi-Fi, Control Center) and only adds fallback entries when new positions appear.
- `MenuExtraInfo` now stores the raw title, bundle, and owner metadata so the CLI can map `com.apple.controlcenter` → “Control Center”, `com.apple.Siri` → “Siri”, etc., and we skip duplicates whenever a new entry overlaps an already-rendered location.

## `menubar list` now includes raw metadata
- **Command**: `polter peekaboo menubar list --json-output`
- **Observed**: Beyond the friendly display string, downstream automation needed the raw bundle/title/owner info for analytics and status item indexing.
- **Resolution — Nov 12, 2025**: `MenuBarItemInfo` now exposes `rawTitle`, `bundleIdentifier`, and `ownerName`, and the JSON schema includes `raw_title`, `bundle_id`, `owner_name` so callers can schedule more precise actions.

## `menu list --json-output` now also reports owner name
- **Command**: `polter peekaboo menu list --json-output`
- **Observed**: Scripts needed a consistent `owner_name` for the targeted app, not just the app title and bundle ID.
- **Resolution — Nov 12, 2025**: The JSON response now returns `owner_name` (set to the resolved application name) alongside `bundle_id`, mirroring the menubar metadata so downstream consumers can use the same schema for both commands.

## Menu structure now carries owner metadata in every node
- **Motivation**: Future tooling may need bundle/owner context even for submenu entries, not just the root app. Adding it to `Menu`/`MenuItem` makes the JSON tree richer without extra API calls.
- **Resolution — Nov 12, 2025**: `Menu` and `MenuItem` structs now expose `bundle_id`/`owner_name`, and the CLI JSON output includes them for every node (the menu command now ships `bundle_id`/`owner_name` alongside `title` for menus and items). Services still populate those fields from the resolved `ServiceApplicationInfo`, so even deeply nested menu entries keep the same owner metadata.

## `window focus` reports INTERNAL_SWIFT_ERROR instead of WINDOW_NOT_FOUND
- **Command**: `polter peekaboo window focus --app Finder --json-output`
- **Observed**: `FocusSubcommand` returned `{ "code": "INTERNAL_SWIFT_ERROR", "message": "Could not find accessibility element for window ID 91" }` when the window could not be focused.
- **Expected**: The CLI should surface `WINDOW_NOT_FOUND` so scripts can detect a missing window and respond (e.g., open a new document).
- **Impact**: Automation flows must parse brittle error strings instead of relying on structured error codes, making retry logic fragile.
### Investigation log — Nov 12, 2025
- `ensureFocused` bubbled up `FocusError.axElementNotFound`, but `ErrorHandlingCommand` only mapped `PeekabooError` and `CaptureError` to structured codes; `FocusError` defaulted to `INTERNAL_SWIFT_ERROR`.
- We needed an explicit mapping from every `FocusError` case to the proper CLI error code.
### Resolution — Nov 12, 2025
- `ErrorHandlingCommand.mapErrorToCode` now intercepts `FocusError` and defers to `errorCode(for:)`, ensuring `WINDOW_NOT_FOUND`, `APP_NOT_FOUND`, or `TIMEOUT` as appropriate.
- Added `FocusErrorMappingTests` to lock in the mapping (including `axElementNotFound` → `WINDOW_NOT_FOUND` and `focusVerificationTimeout` → `TIMEOUT`).

## `type` silently succeeds without a focused field
- **Command**: `polter peekaboo type "Hello"` (no `--app`, no active session)
- **Observed**: CLI prints `✅ Typing completed`, but no characters arrive in TextEdit because nothing ensured the insertion point was active.
- **Expected**: Typing should still be possible for advanced users who deliberately inject keystrokes, but the CLI should warn when it cannot guarantee focus.
### Resolution — Nov 12, 2025
- `TypeCommand` now keeps “blind typing” available yet logs a warning when neither `--app` nor `--session` is supplied under auto-focus. Users still get their keystrokes, but the CLI explicitly suggests running `peekaboo see` or specifying `--app` first so the experience is less confusing.

## Dialog commands ignore macOS Open/Save panels
- **Command**: `polter peekaboo dialog click --button "New Document"`
- **Observed**: `No active dialog window found` even while an `NSOpenPanel` sheet is frontmost (TextEdit’s “New Document / Open” panel).
- **Expected**: Dialog service should treat `NSOpenPanel`/`NSSavePanel` sheets as dialogs so button clicks and file selection work.
### Resolution — Nov 12, 2025
- `DialogService` now inspects `AXFocusedWindow`, recurses through `AXSheets`, checks `AXIdentifier` for `NSOpenPanel`/`NSSavePanel`, and matches titles like “Open”, “Save”, “Export”, or “Import”. Both `dialog list` and `dialog click` successfully locate the TextEdit open panel.

## `dock hide` never returns
- **Command**: `polter peekaboo dock hide`
- **Observed**: Command times out after ~10 s because the AppleScript call to System Events waits for automation approval.
- **Expected**: Dock hide/show should complete quickly without extra permissions.
### Resolution — Nov 12, 2025
- DockService now toggles `com.apple.dock autohide` via `defaults` and restarts the Dock process instead of driving System Events. We also skip the write entirely if the Dock is already in the requested state, so `dock hide`/`dock show` finish in <1 s.

## Dialog commands need faster feedback
- **Command**: `polter peekaboo dialog list --json-output` (no `--app` hint)
- **Observed**: Even with the Open panel visible, the CLI spent ~8s enumerating every running app before returning.
- **Expected**: A user-supplied application hint should skip the global crawl and focus the dialog faster.
### Resolution — Nov 12, 2025
- Added `--app <Application>` to every dialog subcommand (`click/input/file/dismiss/list`). When provided, the CLI focuses that app (and optional window title) before calling DialogService, so the service immediately inspects the correct AX tree. Dialog commands still work without the hint, but now advanced users can cut the worst-case search time down to ~1s.

## Regression coverage for dialog CLI
- **Command**: `swift test --filter DialogCommandTests`
- **Observed**: The existing dialog tests only checked help output, leaving JSON regressions undetected.
- **Expected**: Unit tests should validate the CLI’s JSON payloads without requiring TextEdit to be open.
### Resolution — Nov 12, 2025
- `StubDialogService` can now return canned `DialogElements`/`DialogActionResult` and record button clicks. New harness tests exercise `dialog list --json-output` and `dialog click --json-output` against the stub so the serializer and runner stay verified without manual GUI setup.
