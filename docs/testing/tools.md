---
summary: 'Systematic Peekaboo tool verification plan using Playground and file logs'
read_when:
  - 'planning or executing the comprehensive tool regression pass'
  - 'picking up the Playground-based test assignment'
---

# Peekaboo Tool Playground Test Plan

## Assignment & Expectations
- Validate every native Peekaboo tool/CLI command (see the CLI command reference) against the Playground app so future automation runs have deterministic coverage.
- For each tool run, capture an OSLog transcript with `Apps/Playground/scripts/playground-log.sh --output <file>` so we have durable evidence that the action completed (e.g., `[Click]`, `[Scroll]` entries).
- Update this document every time you start/finish a tool, and log deeper repro notes or bugs under `Apps/Playground/PLAYGROUND_TEST.md` so the next person can keep going.
- Fix any issues you discover while executing the plan. If a fix is large, land it first, then rerun the affected tool plan and refresh the log artifacts.
- Use `polter peekaboo -- <command>` for every CLI invocation so we always hit the freshest binary, and prefer tmux sessions (via `./runner tmux new-session -- <cmd>`) for any run expected to exceed ~1 minute.

## Environment & Logging Setup
1. Ensure Poltergeist is healthy: `npm run poltergeist:status`; start it with `npm run poltergeist:haunt` if needed.
2. Launch Playground (`Apps/Playground/Playground.app` via Xcode or `open Apps/Playground/Playground.xcodeproj`). Keep it foregrounded on Space 1 to avoid focus surprises.
3. Prepare a log root once per session:
   ```bash
   LOG_ROOT=${LOG_ROOT:-$PWD/.artifacts/playground-tools}
   mkdir -p "$LOG_ROOT"
   ```
4. Before you run any Peekaboo tool, arm a category-specific log capture so we can diff pre/post state:
   ```bash
   TOOL=Click   # e.g. Click/Text/Menu/Window/Scroll/Drag/Keyboard/Focus/Gesture/Control/App
   LOG_FILE="$LOG_ROOT/$(date +%Y%m%d-%H%M%S)-${TOOL,,}.log"
   ./Apps/Playground/scripts/playground-log.sh -c "$TOOL" --last 10m --all -o "$LOG_FILE"
   ```
5. Keep the Playground UI on the matching view (ClickTestingView, TextInputView, etc.) and run `polter peekaboo -- see --app Playground` anytime you need a fresh session ID for element targeting. Record the session ID in your notes.
6. After executing the tool, append verification notes (log file path, session ID, observed behavior) to the table below and add detailed findings to `Apps/Playground/PLAYGROUND_TEST.md`.

## Execution Loop
1. Pick a tool from the matrix (start with Interaction tools, then cover window/app utilities, then the remaining system/automation commands).
2. Review the tool doc under `docs/commands/<tool>.md` and skim the command implementation in `Apps/CLI/Sources/PeekabooCLI/Commands/**` so you understand its parameters and edge cases before running it.
3. Stage the Playground view + log capture as described above.
4. Run the suggested CLI smoke tests plus the extra edge cases listed per tool (invalid targets, timing edge cases, multi-step flows).
5. Confirm Playground reflects the action (UI changes + OSLog evidence). Capture screenshots if a regression needs a visual repro.
6. File and fix bugs immediately; rerun the plan for the affected tool to prove the fix.
7. Update the status column and include the log artifact path so the next person knows what already passed.

## Tool Matrix

### Vision & Capture
| Tool | Playground coverage | Log focus | Sample CLI entry point | Status | Latest log |
| --- | --- | --- | --- | --- | --- |
| `see` | Entire Playground main window (any view) | Capture session metadata via CLI output + optional `Click` logs for follow-on actions | `polter peekaboo -- see --app Playground --path /tmp/see-playground.png` | Verified – ScreenCaptureKit path restored and session 5B5A2C09… captures ClickTestingView reliably | `.artifacts/playground-tools/20251116-082056-see-playground.json` |
| `image` | Playground window (full or element-specific) | Use `Image` artifacts; note timestamp in `LOG_FILE` | `polter peekaboo -- image window --app Playground --output /tmp/playground-window.png` | Verified – window + screen captures succeed after capture fallback fix | `.artifacts/playground-tools/20251116-082109-image-window-playground.json`, `.artifacts/playground-tools/20251116-082125-image-screen0.json` |
| `list` | Validate `apps`, `windows`, `screens`, `menubar`, `permissions` while Playground is running | `playground-log` optional (`Window` for focus changes) | `polter peekaboo -- list windows --app Playground` etc. | Verified – apps/windows/screens/menubar/permissions captured 2025-11-16 | `.artifacts/playground-tools/20251116-142111-list-apps.json`, `.artifacts/playground-tools/20251116-142111-list-windows-playground.json`, `.artifacts/playground-tools/20251116-142122-list-screens.json`, `.artifacts/playground-tools/20251116-142122-list-menubar.json`, `.artifacts/playground-tools/20251116-142122-list-permissions.json` |
| `tools` | Compare CLI output against ToolRegistry | No Playground log required; attach JSON to notes | `polter peekaboo -- tools --native-only --json-output` | Verified – native + MCP listings captured 2025-11-16 | `.artifacts/playground-tools/20251116-142009-tools-native.json`, `.artifacts/playground-tools/20251116-142009-tools-mcp.txt` |
| `run` | Execute scripted multi-step flows against Playground fixtures | Logs depend on embedded commands | `polter peekaboo -- run docs/testing/fixtures/playground-smoke.peekaboo.json` | Verified – playground-smoke script | `.artifacts/playground-tools/20251116-050504-run-playground.json` |
| `sleep` | Inserted between Playground actions | Observe timestamps in log file | `polter peekaboo -- sleep 1500` | Verified – manual timing around CLI pause | `python wrapper measuring ./runner polter peekaboo -- sleep 2000` |
| `clean` | Session cache after `see` runs | Inspect `~/.peekaboo/session` & ensure Playground unaffected | `polter peekaboo -- clean --session <id>` | Verified – removed session 5408D893… and confirmed re-run reports none | `.peekaboo/session/5408D893-E9CF-4A79-9B9B-D025BF9C80BE (deleted)` |
| `config` | Validate config commands while Playground idle | N/A | `polter peekaboo -- config show` | Verified – show/validate outputs captured 2025-11-16 | `.artifacts/playground-tools/20251116-051200-config-show-effective.json` |
| `permissions` | Ensure status/grant flow works with Playground | `playground-log` `App` category (should log when permissions toggled) | `polter peekaboo -- permissions status` | Verified – Screen Recording & Accessibility granted | `.artifacts/playground-tools/20251116-051000-permissions-status.json` |
| `learn` | Dump agent guide | N/A | `polter peekaboo -- learn > $LOG_ROOT/learn.txt` | Verified – latest dump saved 2025-11-16 | `.artifacts/playground-tools/20251116-051300-learn.txt` |

### Interaction Tools
| Tool | Playground surface | Log category | Sample CLI | Status | Latest log |
| --- | --- | --- | --- | --- | --- |
| `click` | ClickTestingView buttons/areas | `Click` | `polter peekaboo -- click "Single Click"` | Verified – see session 263F8CD6… w/ log capture | `.artifacts/playground-tools/20251116-051025-click.log` |
| `type` | TextInputView fields | `Text` + `Focus` | `polter peekaboo -- type "Hello Playground" --clear --session <id>` | Verified – basic + number field coverage 2025-11-16 | `.artifacts/playground-tools/20251116-051202-text.log` |
| `press` | KeyboardView key detection field | `Keyboard` | `polter peekaboo -- press return --session <id>` | Verified – return + repeated arrow presses logged, invalid key errors | `.artifacts/playground-tools/20251116-090141-see-keyboardtab.json`, `.artifacts/playground-tools/20251116-090455-keyboard.log` |
| `hotkey` | KeyboardView hotkey text area / menu shortcuts | `Keyboard` & `Menu` | `polter peekaboo -- hotkey --keys "cmd,shift,l" --session <id>` | Verified – logs captured 2025-11-16 | `.artifacts/playground-tools/20251116-051654-keyboard-hotkey.log` |
| `scroll` | ScrollTestingView vertical/horizontal lists | `Scroll` | `polter peekaboo -- scroll --direction down --amount 5 --session <id>` | Verified – CLI + Playground Scroll logs captured 2025-11-16 | `.artifacts/playground-tools/20251116-085714-see-scrolltab.json`, `.artifacts/playground-tools/20251116-085815-scroll.log` |
| `swipe` | Gesture area inside ScrollTestingView | `Gesture` | `polter peekaboo -- swipe --from-coords 1100,520 --to-coords 700,520` | Verified – horizontal + vertical swipes logged (2025-11-16) | `.artifacts/playground-tools/20251116-085714-see-scrolltab.json`, `.artifacts/playground-tools/20251116-090041-gesture.log` |
| `drag` | DragDropView items & drop zones | `Drag` | `polter peekaboo -- drag --session <id> --from elem_15 --to elem_24` | Verified – toggle to Drag tab via `click --on elem_79`, then drag Item A → zone1 | `.artifacts/playground-tools/20251116-085142-see-afterclick-elem79.json`, `.artifacts/playground-tools/20251116-085233-drag.log`, `.artifacts/playground-tools/20251116-085346-drag-elem17.json` |
| `move` | ClickTestingView coordinate targets (e.g., nested area) | `Focus` (cursor move) & `Click` follow-up | `polter peekaboo -- move 600,600` | Verified – coordinate, center, and session-targeted moves succeeding | `.artifacts/playground-tools/20251116-085714-see-scrolltab.json`, `[CLI output only pending Focus logs]` |

### Windows, Menus, Apps
| Tool | Playground validation target | Log category | Sample CLI | Status | Latest log |
| --- | --- | --- | --- | --- | --- |
| `window` | WindowTestingView controls + extra Playground windows | `Window` | `polter peekaboo -- window focus --app Playground` | In progress – instrumentation active (TextEdit run 2025-11-16) | `.artifacts/playground-tools/20251116-073620-window.log` |
| `space` | macOS Spaces while Playground anchored on Space 1 | `Window` (verify frontmost window) | `polter peekaboo -- space list --detailed` | In progress – commands work, no Space log | `.artifacts/playground-tools/20251116-053816-space.log` |
| `menu` | Playground “Test Menu” + context menus | `Menu` | `polter peekaboo -- menu click --path "Test Menu>Test Action 1" --app Playground` | In progress – disabled items incorrectly report success | `.artifacts/playground-tools/20251116-051547-menu.log` |
| `menubar` | macOS menu extras (Wi-Fi, Clock) plus Playground status icons | `Menu` (system) | `polter peekaboo -- menubar list --json-output` | Verified – list + click captured; logs via Control Center predicate | `.artifacts/playground-tools/20251116-053932-menubar.log` |
| `app` | Launch/quit/focus Playground + helper apps (TextEdit) | `App` + `Focus` | `polter peekaboo -- app list --include-hidden --json-output` | In progress – instrumentation now logs actions (2025-11-16) | `.artifacts/playground-tools/20251116-071820-app.log` |
| `open` | Open Playground fixtures/documents | `App`/`Focus` | `polter peekaboo -- open Apps/Playground/README.md --app TextEdit --json-output` | In progress – Open logger emits entries; need more target coverage | `.artifacts/playground-tools/20251116-071740-open.log` |
| `dock` | Dock item interactions w/ Playground icon | `App` + `Window` | `polter peekaboo -- dock list --json-output` | In progress – Dock commands now log hide/show/list/launch | `.artifacts/playground-tools/20251116-071700-dock.log` |
| `dialog` | System dialog triggered from Playground (e.g., File > Open) | `Menu` + `Dialog` logs | `polter peekaboo -- dialog list --app TextEdit` | Verified – spawn Save sheet to test | `.artifacts/playground-tools/20251116-054316-dialog.log` |

### Automation & Integrations
| Tool | Playground coverage | Log category | Sample CLI | Status | Latest log |
| --- | --- | --- | --- | --- | --- |
| `agent` | Run natural-language tasks scoped to Playground (“click the single button”) | Captures whichever sub-tools fire (`Click`, `Text`, etc.) | `polter peekaboo -- agent "Say hi" --max-steps 1` | In progress – agent runs, no Agent log yet | `.artifacts/playground-tools/20251116-054356-agent-list.json` |
| `mcp` | Ensure Playground-focused MCP servers still enumerate & test (esp. Tachikoma) | N/A | `polter peekaboo -- mcp list --json-output` | In progress – list works, `mcp call` crashes Commander | `.artifacts/playground-tools/20251116-055255-mcp-list.json` |

> **Status Legend:** `Not started` = no logs yet, `In progress` = partial run logged, `Blocked` = awaiting fix, `Verified` = passing with log path recorded.

## Per-Tool Test Recipes
The following subsections spell out the concrete steps, required Playground surface, and expected log artifacts for each tool. Check these off (and bump the status above) as you progress.

### Vision & Capture

#### `see`
- **View**: Any (start with ClickTestingView to guarantee clear elements).
- **Steps**:
  1. Bring Playground to front (`polter peekaboo -- app focus Playground`).
  2. `polter peekaboo -- see --app Playground --output "$LOG_ROOT/see-playground.png"`.
  3. Record session ID printed to stdout, verify `~/.peekaboo/session/<id>/map.json` references Playground elements (`single-click-button`, etc.).
- **Log capture**: Optional `Click` capture if you immediately chain interactions with the new session; otherwise store the PNG + session metadata path.
- **Pass criteria**: Session folder exists, UI map contains Playground identifiers, CLI exits 0.
- **2025-11-16 verification**: Re-enabled the ScreenCaptureKit path inside `Core/PeekabooCore/Sources/PeekabooAutomation/Services/Capture/ScreenCaptureService.swift` so the modern API runs before falling back to CGWindowList. `polter peekaboo -- see --app Playground --json-output --path .artifacts/playground-tools/20251116-082056-see-playground.png` now succeeds (session `5B5A2C09-4F4C-4893-B096-C7B4EB38E614`) and drops `.artifacts/playground-tools/20251116-082056-see-playground.{json,png}`.
#### `image`
- **View**: Keep Playground on ScrollTestingView to capture dynamic content.
- **Steps**:
  1. `polter peekaboo -- image window --app Playground --output "$LOG_ROOT/image-playground.png"`.
  2. Repeat with `--screen main --bounds 100,100,800,600` to cover coordinate cropping.
- **2025-11-16 verification**: After restoring the ScreenCaptureKit → CGWindowList fallback order, both window and screen captures succeed. Saved `.artifacts/playground-tools/20251116-082109-image-window-playground.{json,png}` and `.artifacts/playground-tools/20251116-082125-image-screen0.{json,png}`; CLI debug logs still note tiny background windows but the primary Playground window captures at 1200×852.

#### `list`
- **Scenarios**: `list apps`, `list windows --app Playground`, `list screens`, `list menubar`, `list permissions`.
- **Steps**:
  1. With Playground running, execute each subcommand and ensure Playground appears with expected bundle ID/window title.
  2. For `list windows`, compare returned bounds vs. WindowTestingView readout.
  3. For `list menubar`, capture the result and cross-check with actual status items.
- **Logs**: Use `playground-log` `Window` category when forcing focus changes to validate `app focus` interplay.
#### `tools`
- **Steps**:
  1. `polter peekaboo -- tools --native-only --json-output > "$LOG_ROOT/tools-native.json"`.
  2. `polter peekaboo -- tools --mcp-only --group-by-server > "$LOG_ROOT/tools-mcp.txt"`.
  3. Compare native entries to the Interaction/Window commands listed here; flag gaps.
- **Verification**: JSON includes click/type/etc. with descriptions.

#### `run`
- **Setup**: Create a sample `.peekaboo.json` (store under `docs/testing/fixtures/` once defined) that performs `see`, `click`, `type`, and `scroll`.
- **Steps**:
  1. Start Click + Text log captures.
  2. Ensure Playground is showing TextInputView (e.g., `polter peekaboo -- app switch --to Playground` followed by `polter peekaboo -- click --session <see-id> --on <Text Input tab id>`).
  3. `polter peekaboo -- run docs/testing/fixtures/playground-smoke.peekaboo.json --output "$LOG_ROOT/run-playground.json" --json-output`.
  3. Confirm each embedded step produced matching log entries.
- **Notes**: Update fixture when tools change to keep coverage aligned.
- **2025-11-16 run**: Created `docs/testing/fixtures/playground-smoke.peekaboo.json` (focus → see → click Focus Basic Field → type Basic Text Field). Execution succeeded with report `.artifacts/playground-tools/20251116-142711-run-playground.json` (session `1763303232278-2419`) and screenshot artifact `.artifacts/playground-tools/run-script-see.png`. Script will fail if Playground isn’t on the Text Input tab, so click the “Text Input” tab first.

#### `sleep`
- **Steps**:
  1. Run `date +%s` then `polter peekaboo -- sleep 2000` within tmux.
  2. Immediately issue a `click` command and ensure the log timestamps show ≥2s gap.
- **Verification**: Playground log lines prove no action fired during sleep window.
- **2025-11-16 run**: Measured via `python - <<'PY' ... subprocess.run(["./runner","polter","peekaboo","--","sleep","2000"]) ...` → actual pause ≈2.24 s (CLI printed `✅ Paused for 2.0s`). No Playground interaction necessary.

#### `clean`
- **Steps**:
  1. Generate two sessions via `see`.
  2. `polter peekaboo -- clean --older-than 1m` and confirm only newest session remains.
  3. Attempt to interact using purged session ID and assert command fails with helpful error.
- **Artifacts**: Directory listing before/after.
- **2025-11-16 run**: Created sessions `5408D893-…` and `129101F5-…` via back-to-back `see` captures (artifacts saved under `.artifacts/playground-tools/*clean-see*.png`). Ran `polter peekaboo -- clean --session 5408D893-…` (freed 453 KB), verified folder removal (`ls ~/.peekaboo/session`). Re-running the same clean command returned “No sessions to clean”, confirming deletion. Attempting `clean --session 5408D893-…` again yields 0 removals; `click --session 5408D893-…` surfaces a generic “element not found” error—worth improving to mention missing session.

#### `config`
- **Focus**: `config show`, `config validate`, `config models`.
- **Steps**:
  1. Snapshot `~/.peekaboo/config.json` (read-only).
  2. Run `polter peekaboo -- config validate --verbose`.
  3. Document provider list for later cross-check.
- **Notes**: No Playground tie-in; just ensure CLI stability.
- **2025-11-16 run**: `polter peekaboo -- config show --effective --json-output > .artifacts/playground-tools/20251116-051200-config-show-effective.json` plus `polter peekaboo -- config validate` both succeeded; output confirms OpenAI key set + default save path. No edits performed.

#### `permissions`
- **Steps**:
  1. `polter peekaboo -- permissions status` to confirm Accessibility/Screen Recording show Granted.
  2. If a permission is missing, follow docs/permissions.md to re-grant and note the steps.
  3. Capture console output.
- **2025-11-16 run**: `polter peekaboo -- permissions status --json-output > .artifacts/playground-tools/20251116-051000-permissions-status.json` returned both Screen Recording and Accessibility as granted (matching expectations); no Playground interaction required.

#### `learn`
- **Steps**: `polter peekaboo -- learn > "$LOG_ROOT/learn-latest.txt"`; record commit hash displayed at top.
- **2025-11-16 run**: Saved `.artifacts/playground-tools/20251116-051300-learn.txt` for reference; includes commit metadata from peekaboo binary.

### Interaction Tools

#### `click`
- **View**: ClickTestingView.
- **Log capture**: `./Apps/Playground/scripts/playground-log.sh -c Click --last 10m --all -o "$LOG_ROOT/click-$(date +%s).log"`.
- **Test cases**:
  1. Query-based click: `polter peekaboo -- click "Single Click"` (expect `Click` log + counter increment).
  2. ID-based click: `polter peekaboo -- click --on B1 --session <id>` targeting `single-click-button`.
  3. Coordinate click: `polter peekaboo -- click --coords 400,400` hitting the nested area.
  4. Error path: attempt to click disabled button and confirm descriptive `elementNotFound` guidance.
- **Verification**: Playground counter increments, log file shows `[Click] Single click...` entries.
- **2025-11-16 run**:
  - Captured Click logs to `.artifacts/playground-tools/20251116-051025-click.log`.
  - Generated fresh session `263F8CD6-E809-4AC6-A7B3-604704095011` via `see` (`.artifacts/playground-tools/20251116-051120-click-see.{json,png}`).
  - `polter peekaboo -- click "Single Click" --session <legacy session>` succeeded but targeted Ghostty (click hit terminal input); highlighting importance of focusing Playground first.
  - `polter peekaboo -- app switch --to Playground` followed by `polter peekaboo -- click --on elem_6 --session 263F8CD6-...` successfully hit the “View Logs” button (Playground log recorded the click).
  - Coordinate click `--coords 600,500` succeeded (see log); attempting `--on elem_disabled` produced expected `elementNotFound` error.
  - IDs like `B1` are not stable in this build; rely on `elem_*` IDs from the `see` output.

#### `type`
- **View**: TextInputView.
- **Log capture**: `Text` + `Focus` categories.
- **Test cases**:
  1. `polter peekaboo -- type "Hello Playground" --query "Basic"` to fill the basic field.
  2. Use `--clear` then `--append` flows to verify editing.
  3. Tab-step typing with `--tabs 2` into the secure field.
  4. Unicode input (emoji) to ensure no crash.
- **Verification**: Field contents update, log shows `[Text] Basic field changed` entries.
- **2025-11-16 run**:
  - Logged `.artifacts/playground-tools/20251116-051202-text.log`.
  - Focused field via `polter peekaboo -- click "Focus Basic Field" --session 263F8CD6-…` (session from `.artifacts/playground-tools/20251116-051120-click-see.json`).
  - `polter peekaboo -- type "Hello Playground" --clear --session 263F8CD6-…` updated the Basic Text Field (log shows “Basic text changed …”).
  - `polter peekaboo -- type --tab 1 --session 263F8CD6-…` advanced focus to the Number field, followed by `polter peekaboo -- type "42" --session 263F8CD6-…`.
  - Validation error confirmed via `polter peekaboo -- type "bad" --profile warp` (proper error message).
  - Note: targets are determined by current focus; use helper buttons and `click` to focus before typing. Legacy `--on` / `--query` flags no longer exist.

#### `press`
- **View**: KeyboardView “Key Press Detection” field (Keyboard tab).
- **Test cases**:
  1. `polter peekaboo -- press return --session <id>` after focusing the detection text field.
  2. `polter peekaboo -- press up --count 3 --session <id>` to ensure repeated presses log individually.
  3. Invalid key handling (`polter peekaboo -- press foo`) should error.
- **2025-11-16 verification**:
  - Switched to the Keyboard tab via `polter peekaboo -- hotkey --keys "cmd,option,7"`, captured `.artifacts/playground-tools/20251116-090141-see-keyboardtab.{json,png}` (session `C106D508-930C-4996-A4F4-A50E2E0BA91A`), and focused the “Press keys here…” field with a coordinate click (`--coords 760,300`).
  - `polter peekaboo -- press return --session C106D508-…` and `polter peekaboo -- press up --count 3 --session C106D508-…` produced `[boo.peekaboo.playground:Keyboard] Key pressed: …` entries in `.artifacts/playground-tools/20251116-090455-keyboard.log`.
  - `polter peekaboo -- press foo` reports `Unknown key: 'foo'. Run 'peekaboo press --help' for available keys.` confirming validation and documenting the negative path.

#### `hotkey`
- **View**: KeyboardView hotkey demo or main window (use `cmd+shift+l` to open log viewer).
- **Test cases**:
  1. `polter peekaboo -- hotkey cmd,shift,l` should toggle the “Clear All Logs” command (log viewer clears entries).
  2. `polter peekaboo -- hotkey cmd,1` to trigger Test Menu action; watch `Menu` logs.
  3. Negative test: provide invalid chord order to ensure validation message.
- **Verification**: Playground `Keyboard` log file shows the keystrokes fired.
- **2025-11-16 run**:
  - Logs stored at `.artifacts/playground-tools/20251116-051654-keyboard-hotkey.log` (contains entries for `L` and `1` corresponding to the combos).
  - `polter peekaboo -- hotkey --keys "cmd,shift,l" --session 11227301-05DE-4540-8BE7-617F99A74156` (clears logs via shortcut).
  - `polter peekaboo -- hotkey --keys "cmd,1" --session …` switches Playground tabs.
  - `polter peekaboo -- hotkey --keys "foo,bar"` correctly fails with `Unknown key: 'foo'`.

#### `scroll`
- **View**: ScrollTestingView vertical/horizontal sections (switch using `polter peekaboo -- hotkey --keys "cmd,option,4"` to trigger the new Test Menu shortcut).
- **Test cases**:
  1. `polter peekaboo -- scroll --direction down --amount 6 --session <id>` for vertical movement.
  2. `polter peekaboo -- scroll --direction right --amount 4 --smooth --session <id>` for horizontal smooth scrolling.
  3. Negative path: `--on vertical-scroll` still fails until ScrollTestingView exposes those identifiers in `see`.
- **2025-11-16 verification**:
  - Captured session `.artifacts/playground-tools/20251116-085714-see-scrolltab.{json,png}` (session `DBFDD053-4513-4603-B7C3-9170E7386BA7`), then ran the down/right commands above. `playground-log.sh -c Scroll` recorded both CLI automation entries in `.artifacts/playground-tools/20251116-085815-scroll.log` (showing the `[boo.peekaboo.playground:Scroll]` lines).
  - `polter peekaboo -- scroll --session DBFDD053-… --direction down --amount 2 --on vertical-scroll` still raises `Element not found: vertical-scroll`, confirming ScrollTestingView doesn’t surface those identifiers in `see` yet. Leave this as a known follow-up.

#### `swipe`
- **View**: Gesture Testing area.
- **Test cases**:
  1. `polter peekaboo -- swipe --from-coords 1100,520 --to-coords 700,520 --duration 600`.
  2. `polter peekaboo -- swipe --from-coords 850,600 --to-coords 850,350 --duration 800 --profile human`.
  3. Negative test: `polter peekaboo -- swipe … --right-button` should error.
- **2025-11-16 verification**:
  - Used session `DBFDD053-4513-4603-B7C3-9170E7386BA7` (see `.artifacts/playground-tools/20251116-085714-see-scrolltab.{json,png}`) to keep the tab selection stable.
  - Horizontal and vertical commands above completed successfully; Playground log `.artifacts/playground-tools/20251116-090041-gesture.log` shows `[boo.peekaboo.playground:Gesture]` entries with exact coordinates, profiles, and step counts.
  - `polter peekaboo -- swipe --from-coords 900,520 --to-coords 700,520 --right-button` returns `Right-button swipe is not currently supported…`, matching expectations.

#### `drag`
- **View**: DragDropView (tab is hidden on launch—run `polter peekaboo -- click --session <id> --on elem_79` right after `see` to activate the “Drag & Drop” tab radio button).
- **Test cases**:
  1. Drag Item A (`elem_15`) into drop zone 1 (`elem_24`) via `--from/--to`.
  2. Drag Item B (`elem_17`) into drop zone 2 (`elem_26`) and capture JSON output for artifacting.
  3. (Optional) Drag the reorderable list rows (`elem_37`…`elem_57`) once additional coverage is needed.
- **2025-11-16 verification**:
  - A reusable `PlaygroundTabRouter` + header “Go to Drag & Drop” control keep the TabView state predictable, and more importantly `elem_79` now works deterministically—clicking it flips the TabView so subsequent `see` runs expose DragDropView element IDs (see `.artifacts/playground-tools/20251116-085142-see-afterclick-elem79.{json,png}` with session `BBF9D6B9-26CB-4370-8460-6C8188E7466C`).
  - `polter peekaboo -- drag --session BBF9D6B9-26CB-4370-8460-6C8188E7466C --from elem_15 --to elem_24 --duration 800 --steps 40` succeeded; Playground log `.artifacts/playground-tools/20251116-085233-drag.log` shows “Started dragging: Item A”, “Hovering over zone1”, and “Item dropped… zone1”, plus the CLI-side `[boo.peekaboo.playground:Drag] drag from=…` entry.
  - Captured a second run with JSON output (`.artifacts/playground-tools/20251116-085346-drag-elem17.json`) dragging Item B to zone2 so we have structured metadata (coords, duration, profile) for regression diffs.
  - We still keep the older coordinate-only recipe around as a fallback, but the default regression loop is now: **focus Playground → `see` → `click --on elem_79` → `drag --session … --from elem_XX --to elem_YY` → archive the Drag log + CLI JSON.**

#### `move`
- **View**: ClickTestingView (target nested button) or ScrollTestingView.
- **Test cases**:
  1. `polter peekaboo -- move 600,600` for instant pointer relocation.
  2. Smooth query-based move: `polter peekaboo -- move --to "Focus Basic Field" --session <id> --smooth`.
  3. `polter peekaboo -- move --center --duration 300 --steps 15`.
  4. (Optional) Attempting invalid coordinates currently produces an “Unknown option” error because `move` expects positional coords; leave TODO for future validation messaging.
- **2025-11-16 verification**:
  - Commands above rerun with session `DBFDD053-4513-4603-B7C3-9170E7386BA7`; CLI outputs saved implicitly (no JSON mode). Pointer jumps succeeded (`move 600,600`, `move --center`).
  - `move --to "Focus Basic Field" --session ... --smooth` works with session-based targeting; repeated runs confirm the lookup is stable.
  - Focus logger still doesn’t capture these events (`playground-log -c Focus` remains empty), so we rely on CLI output for evidence until instrumentation is added.

### Windows, Menus, Apps

#### `window`
- **View**: WindowTestingView (or any app with a movable window; Playground itself works for focus/move/resize).
- **Test cases**:
  1. `polter peekaboo -- window focus --app Playground`.
  2. `polter peekaboo -- window move --app Playground -x 100 -y 100`.
  3. `polter peekaboo -- window resize --app Playground --width 900 --height 600`.
  4. `polter peekaboo -- window set-bounds --app Playground --x 200 --y 200 --width 1100 --height 700`.
  5. `polter peekaboo -- window list --app Playground --json-output`.
- **2025-11-16 verification**:
  - Commands run with Playground as the target; artifacts include `.artifacts/playground-tools/20251116-141723-window-list-playground.json`.
  - Window log `.artifacts/playground-tools/20251116-141610-window.log` shows `[Window] focus`, `move`, `resize`, and `set-bounds` entries with bounds metadata, confirming instrumentation.

#### `space`
- **Scenario**: Single Space (current setup). Need additional Space to test multi-space behavior.
- **Test cases**:
  1. `polter peekaboo -- space list --detailed --json-output`.
  2. `polter peekaboo -- space switch --to 1` (happy path) and expect error for `--to 2` when only one Space exists.
  3. `polter peekaboo -- space move-window --app Playground --to 1 --follow`.
- **2025-11-16 run**:
  - Commands above executed again with fresh artifacts:
    - `.artifacts/playground-tools/20251116-091557-space-list.json` (`space list --detailed`)
    - `.artifacts/playground-tools/20251116-091602-space-switch-2.json` (expected `VALIDATION_ERROR` when targeting Space 2)
    - `space move-window --app Playground --to 1 --follow` (no-op but validates command flow)
  - Environment still exposes only one space (IDs 1-1). CLI error message remains descriptive when requesting Space 2.
  - `playground-log.sh -c Space` still produces an empty file (`.artifacts/playground-tools/20251116-091632-space.log`)—there’s no dedicated `Space` logger yet, which is worth tracking for future instrumentation.

#### `menu`
- **View**: Playground’s “Test Menu” items (standard menu bar). Context menus on the `right-click-area` still require `click` rather than `menu` because `menu click` doesn’t accept coordinate targets yet.
- **Test cases**:
  1. `polter peekaboo -- menu click --app Playground --path "Test Menu>Test Action 1"`.
  2. `polter peekaboo -- menu click --app Playground --path "Test Menu>Submenu>Nested Action A"`.
  3. Disabled menu handling: `polter peekaboo -- menu click --app Playground --path "Test Menu>Disabled Action"` should fail with a descriptive error.
- **2025-11-16 verification**:
  - Listed the menu tree via `polter peekaboo -- menu list --app Playground --json-output > .artifacts/playground-tools/20251116-090600-menu-playground.json` (shows Test Menu entries + Submenu).
  - Commands above succeeded and logged `[Menu] Test Action 1 clicked` / `Submenu > Nested Action A clicked` in `.artifacts/playground-tools/20251116-090512-menu.log`.
  - Disabled item command now emits `Menu item is disabled: Test Menu > Disabled Action` with code `INTERACTION_FAILED` (see `.artifacts/playground-tools/20251116-090509-menu-click-disabled.json`).
  - Context menu coverage remains TBD; `menu click` currently targets menu-bar entries only.

#### `menubar`
- **Target**: macOS status items (Wi-Fi, Battery) or custom extras.
- **Test cases**:
  1. `polter peekaboo -- menubar list --json-output > .artifacts/playground-tools/20251116-141824-menubar-list.json`.
  2. `polter peekaboo -- menubar click "Wi-Fi"` (or `--index 9`) and close Control Center manually afterward.
  3. `polter peekaboo -- menubar click --index 2` to exercise Control Center by index.
- **2025-11-16 run**: Commands above succeeded; no dedicated Playground log yet (menu bar actions don’t flow through the app logger). The new list artifact reflects the current order, and the CLI output confirms the clicked items (Wi-Fi and Control Center).

#### `app`
- **Scenarios**:
  1. `polter peekaboo -- app list --include-hidden --json-output > $LOG_ROOT/app-list.json`
  2. `polter peekaboo -- app switch --to Playground`
  3. `polter peekaboo -- app hide --app Playground` / `polter peekaboo -- app unhide --app Playground`
  4. `polter peekaboo -- app launch "TextEdit" --json-output` followed by `polter peekaboo -- app quit --app TextEdit --json-output`
- **2025-11-16 verification**:
  - Newly captured artifacts: `.artifacts/playground-tools/20251116-090750-app-list.json`, `...-090831-app-launch-textedit.json`, `...-090837-app-quit-textedit.json`.
  - Playground log `.artifacts/playground-tools/20251116-090840-app.log` shows the entire sequence (`list`, `switch`, `hide`, `unhide`, `launch`, `quit`) with bundle IDs/PIDs, confirming `AutomationEventLogger` coverage.

#### `open`
- **Tests**:
  1. `polter peekaboo -- open Apps/Playground/README.md --app TextEdit --json-output > .artifacts/playground-tools/20251116-091415-open-readme-textedit.json`.
  2. `polter peekaboo -- open https://example.com --json-output > .artifacts/playground-tools/20251116-091422-open-example.json`.
  3. `polter peekaboo -- open Apps/Playground/README.md --app TextEdit --no-focus --json-output > .artifacts/playground-tools/20251116-091435-open-readme-textedit-nofocus.json`.
- **2025-11-16 verification**: The new runs succeeded; `.artifacts/playground-tools/20251116-091445-open-open.log` shows three `[Open]` entries (TextEdit focused, Chrome focused, TextEdit unfocused). Use these artifacts to prove both app-specific and browser-based opens plus the `--no-focus` behavior.

#### `dock`
- **Tests**:
  1. `polter peekaboo -- dock list --json-output` (artifact `.artifacts/playground-tools/20251116-090944-dock-list.json`).
  2. `polter peekaboo -- dock launch Playground`.
  3. `polter peekaboo -- dock hide` / `polter peekaboo -- dock show`.
  4. `polter peekaboo -- dock right-click --app Finder --select "New Finder Window"`.
- **2025-11-16 verification**:
  - The commands above succeeded; CLI outputs confirm each action and `AutomationEventLogger` recorded them in `.artifacts/playground-tools/20251116-091019-dock.log` (list, launch, hide, show, right_click entries).
  - Right-click command produced JSON at `.artifacts/playground-tools/20251116-091016-dock-right-click.json`, showing `selectedItem : "New Finder Window"`.

#### `dialog`
- **Scenario**: Trigger TextEdit’s Save panel so dialog tooling has something to attach to.
- **Steps to spawn dialog**:
  1. `polter peekaboo -- app launch TextEdit --wait-until-ready --json-output > .artifacts/playground-tools/20251116-091212-textedit-launch.json`.
  2. `polter peekaboo -- menu click --path "File>New" --app TextEdit` to create a blank document.
  3. `polter peekaboo -- see --app TextEdit --json-output --path ...` to capture a session ID (e.g., `0485162B-6D02-4A72-9818-48C79452AEAC`).
  4. `polter peekaboo -- hotkey --keys "cmd,s" --session <id>` to summon the Save dialog.
- **Tests**:
  1. `polter peekaboo -- dialog list --app TextEdit --json-output > .artifacts/playground-tools/20251116-091255-dialog-list.json`.
  2. `polter peekaboo -- dialog click --button "Cancel" --app TextEdit --json-output > .artifacts/playground-tools/20251116-091259-dialog-click-cancel.json`.
- **2025-11-16 verification**:
  - The list call enumerated the Save sheet (“Untitled Dialog”, two buttons, two text fields). The click call dismissed the dialog.
  - `.artifacts/playground-tools/20251116-091306-dialog.log` contains both automation events (`action=list`, `action=click button='Cancel'`), proving the logger instrumentation.
  - Repeat the `hotkey` step whenever you need to reopen the dialog for further testing.

### Automation & Integrations

#### `agent`
- **Scope**: Playground-specific instructions to exercise multiple tools automatically.
- **Tests**:
  1. `polter peekaboo -- agent --list-sessions --json-output > .artifacts/playground-tools/20251116-091814-agent-list.json`.
  2. `polter peekaboo -- agent "Say hi" --max-steps 1 --json-output > .artifacts/playground-tools/20251116-091820-agent-hi.json`.
  3. `polter peekaboo -- agent "Summarize the Playground UI" --dry-run --max-steps 2 --json-output > .artifacts/playground-tools/20251116-091831-agent-toolbar.json`.
- **2025-11-16 run**: Commands succeeded; `[Agent]` log lines recorded in `.artifacts/playground-tools/20251116-091839-agent.log` (task name, model, duration, dry-run flag). Use these artifacts to prove both live and dry-run invocations.

#### `mcp`
- **Steps**:
  1. `polter peekaboo -- mcp list --json-output > .artifacts/playground-tools/20251116-091934-mcp-list.json`.
  2. (Future) `polter peekaboo -- mcp test <server>` once servers are provisioned locally.
  3. `polter peekaboo -- mcp call chrome-devtools navigate_page --args '{"url":"https://example.com"}' --json-output > .artifacts/playground-tools/20251116-171250-mcp-call-chrome-nav.json`.
  4. Optional: `polter peekaboo -- mcp call chrome-devtools evaluate_script --args '{"function":"() => { console.log(\"Peekaboo console\"); return \"ok\"; }"}' --json-output > .artifacts/playground-tools/20251116-171356-mcp-call-chrome-eval.json`.
- **2025-11-16 status**:
  - `mcp list` succeeds (see artifact above) but takes ~45s because no servers respond quickly in this environment.
  - `mcp call chrome-devtools navigate_page` succeeds when chrome-devtools-mcp is launched with `--isolated` (Peekaboo now appends that flag automatically). The response confirms the URL load and selected tab.
  - Additional calls (e.g., `evaluate_script`) also succeed, but note that each `mcp call` launches a fresh chrome-devtools-mcp instance, so commands that rely on shared console/network history (such as `list_console_messages`) will return empty unless everything happens inside a single invocation.
  - Instrumentation (`tachikoma.mcp.*` logs + optional `MCP_STDIO_STDOUT=/tmp/*.log`) shows stdout/stderr flowing normally after the transport refactor. Still no dedicated Playground `[MCP]` logger (`playground-log -c MCP` is empty), so rely on the CLI artifacts until we wire in `AutomationEventLogger`.

## Reporting & Follow-Up
- Record every executed test case (command, arguments, session ID, log file path, outcome) in `Apps/Playground/PLAYGROUND_TEST.md`.
- When a bug is fixed, update this doc’s table row to `Verified` and link to the log artifact plus commit hash.
- If a tool is blocked (e.g., Swift compiler crash), set status to `Blocked`, explain the reason inline, and add a TODO referencing the GitHub issue/Swift crash log.
- Keep this plan synchronized with any changes under `docs/commands/`—when new tools land, add rows + recipes immediately so coverage never regresses.
