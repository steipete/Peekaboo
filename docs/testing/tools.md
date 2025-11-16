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
| `see` | Entire Playground main window (any view) | Capture session metadata via CLI output + optional `Click` logs for follow-on actions | `polter peekaboo -- see --app Playground --output /tmp/see-playground.png` | Ready – Playground now builds with ad-hoc signing | `./runner xcodebuild -project Apps/Playground/Playground.xcodeproj -scheme Playground -destination 'platform=macOS,arch=arm64' build` (2025-11-16) |
| `image` | Playground window (full or element-specific) | Use `Image` artifacts; note timestamp in `LOG_FILE` | `polter peekaboo -- image window --app Playground --output /tmp/playground-window.png` | Not started | – |
| `list` | Validate `apps`, `windows`, `screens`, `menubar`, `permissions` while Playground is running | `playground-log` optional (`Window` for focus changes) | `polter peekaboo -- list windows --app Playground` etc. | Not started | – |
| `tools` | Compare CLI output against ToolRegistry | No Playground log required; attach JSON to notes | `polter peekaboo -- tools --native-only --json-output` | Not started | – |
| `run` | Execute scripted multi-step flows against Playground fixtures | Logs depend on embedded commands | `polter peekaboo -- run docs/testing/fixtures/playground-click.json` (sample) | Not started | – |
| `sleep` | Inserted between Playground actions | Observe timestamps in log file | `polter peekaboo -- sleep 1500` | Not started | – |
| `clean` | Session cache after `see` runs | Inspect `~/.peekaboo/session` & ensure Playground unaffected | `polter peekaboo -- clean --session <id>` | Not started | – |
| `config` | Validate config commands while Playground idle | N/A | `polter peekaboo -- config show` | Not started | – |
| `permissions` | Ensure status/grant flow works with Playground | `playground-log` `App` category (should log when permissions toggled) | `polter peekaboo -- permissions status` | Not started | – |
| `learn` | Dump agent guide | N/A | `polter peekaboo -- learn > $LOG_ROOT/learn.txt` | Not started | – |

### Interaction Tools
| Tool | Playground surface | Log category | Sample CLI | Status | Latest log |
| --- | --- | --- | --- | --- | --- |
| `click` | ClickTestingView buttons/areas | `Click` | `polter peekaboo -- click "Single Click"` | Not started | – |
| `type` | TextInputView fields | `Text` + `Focus` | `polter peekaboo -- type "Hello" --on T3` | Not started | – |
| `press` | KeyboardView special key blocks | `Keyboard` | `polter peekaboo -- press enter` | Not started | – |
| `hotkey` | KeyboardView hotkey text area / menu shortcuts | `Keyboard` & `Menu` | `polter peekaboo -- hotkey cmd,shift,l` | Not started | – |
| `scroll` | ScrollTestingView vertical/horizontal lists | `Scroll` | `polter peekaboo -- scroll down --pixels 600 --on B15` | Not started | – |
| `swipe` | Gesture area inside ScrollTestingView | `Gesture` | `polter peekaboo -- swipe left --duration 0.5 --coords 900,400` | Not started | – |
| `drag` | DragDropView items & drop zones | `Drag` | `polter peekaboo -- drag --from "draggable-item" --to "drop-zone"` | Not started | – |
| `move` | ClickTestingView coordinate targets (e.g., nested area) | `Focus` (cursor move) & `Click` follow-up | `polter peekaboo -- move --coords 500,500` | Not started | – |

### Windows, Menus, Apps
| Tool | Playground validation target | Log category | Sample CLI | Status | Latest log |
| --- | --- | --- | --- | --- | --- |
| `window` | WindowTestingView controls + extra Playground windows | `Window` | `polter peekaboo -- window focus --app Playground` | Not started | – |
| `space` | macOS Spaces while Playground anchored on Space 1 | `Window` (verify frontmost window) | `polter peekaboo -- space list` / `--switch 2` | Not started | – |
| `menu` | Playground “Test Menu” + context menus | `Menu` | `polter peekaboo -- menu click "Test Action 1" --app Playground` | Not started | – |
| `menubar` | macOS menu extras (Wi-Fi, Clock) plus Playground status icons | `Menu` (system) | `polter peekaboo -- menubar click "Wi-Fi"` | Not started | – |
| `app` | Launch/quit/focus Playground + helper apps (TextEdit) | `App` + `Focus` | `polter peekaboo -- app focus Playground` | Not started | – |
| `open` | Open Playground fixtures/documents | `App`/`Focus` | `polter peekaboo -- open Apps/Playground/README.md --app TextEdit` | Not started | – |
| `dock` | Dock item interactions w/ Playground icon | `App` + `Window` | `polter peekaboo -- dock launch Playground` | Not started | – |
| `dialog` | System dialog triggered from Playground (e.g., File > Open) | `Menu` + `Dialog` logs | `polter peekaboo -- dialog list --title "Open"` | Not started | – |

### Automation & Integrations
| Tool | Playground coverage | Log category | Sample CLI | Status | Latest log |
| --- | --- | --- | --- | --- | --- |
| `agent` | Run natural-language tasks scoped to Playground (“click the single button”) | Captures whichever sub-tools fire (`Click`, `Text`, etc.) | `polter peekaboo -- agent "In Playground, click the Single Click button" --dry-run=false` | Not started | – |
| `mcp` | Ensure Playground-focused MCP servers still enumerate & test (esp. Tachikoma) | N/A | `polter peekaboo -- mcp list` / `--mcp call <tool>` | Not started | – |

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
#### `image`
- **View**: Keep Playground on ScrollTestingView to capture dynamic content.
- **Steps**:
  1. `polter peekaboo -- image window --app Playground --output "$LOG_ROOT/image-playground.png"`.
  2. Repeat with `--screen main --bounds 100,100,800,600` to cover coordinate cropping.
- **Verification**: Inspect PNG to confirm ScrollTestingView content; note OS build timestamp from CLI.
- **Logs**: Not action-driven; just store the file path alongside CLI stdout.

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
  2. `polter peekaboo -- run docs/testing/fixtures/playground-smoke.json --output "$LOG_ROOT/run-playground.json"`.
  3. Confirm each embedded step produced matching log entries.
- **Notes**: Update fixture when tools change to keep coverage aligned.

#### `sleep`
- **Steps**:
  1. Run `date +%s` then `polter peekaboo -- sleep 2000` within tmux.
  2. Immediately issue a `click` command and ensure the log timestamps show ≥2s gap.
- **Verification**: Playground log lines prove no action fired during sleep window.

#### `clean`
- **Steps**:
  1. Generate two sessions via `see`.
  2. `polter peekaboo -- clean --older-than 1m` and confirm only newest session remains.
  3. Attempt to interact using purged session ID and assert command fails with helpful error.
- **Artifacts**: Directory listing before/after.

#### `config`
- **Focus**: `config show`, `config validate`, `config models`.
- **Steps**:
  1. Snapshot `~/.peekaboo/config.json` (read-only).
  2. Run `polter peekaboo -- config validate --verbose`.
  3. Document provider list for later cross-check.
- **Notes**: No Playground tie-in; just ensure CLI stability.

#### `permissions`
- **Steps**:
  1. `polter peekaboo -- permissions status` to confirm Accessibility/Screen Recording show Granted.
  2. If a permission is missing, follow docs/permissions.md to re-grant and note the steps.
  3. Capture console output.

#### `learn`
- **Steps**: `polter peekaboo -- learn > "$LOG_ROOT/learn-latest.txt"`; record commit hash displayed at top.

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

#### `type`
- **View**: TextInputView.
- **Log capture**: `Text` + `Focus` categories.
- **Test cases**:
  1. `polter peekaboo -- type "Hello Playground" --query "Basic"` to fill the basic field.
  2. Use `--clear` then `--append` flows to verify editing.
  3. Tab-step typing with `--tabs 2` into the secure field.
  4. Unicode input (emoji) to ensure no crash.
- **Verification**: Field contents update, log shows `[Text] Basic field changed` entries.

#### `press`
- **View**: KeyboardView “Key Press Detection”.
- **Test cases**:
  1. `polter peekaboo -- press enter` (log should display `Return`).
  2. `polter peekaboo -- press up --count 3` (ensure repeated logs).
  3. Invalid key handling (`--press foobar`), expect validation error.

#### `hotkey`
- **View**: KeyboardView hotkey demo or main window (use `cmd+shift+l` to open log viewer).
- **Test cases**:
  1. `polter peekaboo -- hotkey cmd,shift,l` should toggle the “Clear All Logs” command (log viewer clears entries).
  2. `polter peekaboo -- hotkey cmd,1` to trigger Test Menu action; watch `Menu` logs.
  3. Negative test: provide invalid chord order to ensure validation message.

#### `scroll`
- **View**: ScrollTestingView vertical/horizontal sections.
- **Test cases**:
  1. `polter peekaboo -- scroll down --pixels 800 --on vertical-scroll` and confirm log shows reaching bottom.
  2. Horizontal scroll via `--direction right` targeting `horizontal-scroll`.
  3. `--smooth` vs. default to ensure no regressions.

#### `swipe`
- **View**: Gesture Testing area.
- **Test cases**:
  1. `polter peekaboo -- swipe left --coords 900,450 --distance 300` should log `Swipe left`.
  2. Vertical swipe with `--direction up`.
  3. Check `--steps` unusual values.

#### `drag`
- **View**: DragDropView.
- **Test cases**:
  1. Drag `draggable-1` to `drop-zone zone2` via `--source-id`/`--destination-id`.
  2. Drag by coordinates across the free-form area.
  3. Drag-to-reorder list using `--list-index` helpers.
- **Verification**: Log entries like `Item dropped in zone2` and UI updates.

#### `move`
- **View**: ClickTestingView (target nested button) or ScrollTestingView.
- **Test cases**:
  1. `polter peekaboo -- move --coords 300,300` and immediately follow with `click --coords 300,300` to confirm pointer location.
  2. `--duration 0.5` smooth move verifying `Focus` log.
  3. Invalid coordinates (<0) to test validation.

### Windows, Menus, Apps

#### `window`
- **View**: WindowTestingView.
- **Test cases**:
  1. `polter peekaboo -- window focus --app Playground` (Window log should say “Window brought to front”).
  2. `polter peekaboo -- window resize --width 600 --height 400 --app Playground` and confirm view updates.
  3. `polter peekaboo -- window move --x 0 --y 0 --app Playground` verifying coordinates.
  4. Closing extra windows via `--id` after opening the Log Viewer.

#### `space`
- **Scenario**: Create two Spaces (Mission Control). Keep Playground on Space 1, Xcode on Space 2.
- **Test cases**:
  1. `polter peekaboo -- space list` to capture IDs.
  2. `polter peekaboo -- space switch --index 2` while logging `Window` category to ensure Playground loses focus.
  3. `--move-window Playground --to 1` to bring it back; confirm focus.

#### `menu`
- **View**: App menus + ClickTestingView context menu.
- **Test cases**:
  1. `polter peekaboo -- menu click "Test Menu > Test Action 1" --app Playground`.
  2. Context menu invocation on `right-click-area` using `menu click --coords ... --menu "Context Action 2"`.
  3. Handling disabled menu entries (expect descriptive failure).

#### `menubar`
- **Target**: macOS status items (Wi-Fi, Battery) or custom extras.
- **Test cases**:
  1. `polter peekaboo -- menubar list` to snapshot positions.
  2. `polter peekaboo -- menubar click "Wi-Fi"` (watch for Control Center opening) then close it.
  3. Use index-based selection to ensure ordering works.
- **Logs**: Use `log show --predicate 'process == "ControlCenter"'` if Playground logs are insufficient; note this in findings.

#### `app`
- **Scenarios**:
  1. `polter peekaboo -- app focus Playground`.
  2. `polter peekaboo -- app hide Playground` followed by `--unhide`.
  3. `polter peekaboo -- app launch TextEdit --wait-until-ready` to confirm cross-app flows.
- **Verification**: `Window` log entries, plus manual observation.

#### `open`
- **Tests**:
  1. `polter peekaboo -- open Apps/Playground/README.md --app TextEdit --wait-until-ready`.
  2. `open --app Playground --url https://example.com` to ensure Scheme handling.
  3. Validate JSON output mode for automation.

#### `dock`
- **Tests**:
  1. `polter peekaboo -- dock launch Playground`.
  2. `dock right-click Safari` verifying context menu handling.
  3. `dock hide` / `dock show` to confirm state toggles.
- **Verification**: Visual Dock changes + `App` logs (if any).

#### `dialog`
- **Scenario**: Trigger `File > Open` inside Playground (`cmd+shift+o` or via menu) so a standard panel appears.
- **Tests**:
  1. `polter peekaboo -- dialog list` to capture the panel.
  2. `dialog click --title "Open" --button "Cancel"`.
  3. `dialog file --path ~/Desktop/test.txt` to ensure file fields can be populated.
- **Logs**: Use `playground-log` `Menu` + macOS `log show --predicate 'process == "NSOpenPanel"'` for evidence.

### Automation & Integrations

#### `agent`
- **Scope**: Playground-specific instructions to exercise multiple tools automatically.
- **Tests**:
  1. `polter peekaboo -- agent "Capture Playground, click Single Click, then type 'done'" --model gpt-5.1`.
  2. Replay/resume via `--resume <id>` to ensure caching works.
  3. Evaluate dry-run output for accuracy.
- **Verification**: Combined Click/Text logs match planner steps; store `agent-log.json` with conversation transcript.

#### `mcp`
- **Steps**:
  1. `polter peekaboo -- mcp list` ensures Tachikoma servers register.
  2. `polter peekaboo -- mcp test tachikoma` and capture output.
  3. `mcp call <tool>` (e.g., `peekaboo.tools.click`) while Playground is active to ensure bridging works.
- **Notes**: Attach resulting JSON; Playground logs will reflect whichever native commands fire.

## Reporting & Follow-Up
- Record every executed test case (command, arguments, session ID, log file path, outcome) in `Apps/Playground/PLAYGROUND_TEST.md`.
- When a bug is fixed, update this doc’s table row to `Verified` and link to the log artifact plus commit hash.
- If a tool is blocked (e.g., Swift compiler crash), set status to `Blocked`, explain the reason inline, and add a TODO referencing the GitHub issue/Swift crash log.
- Keep this plan synchronized with any changes under `docs/commands/`—when new tools land, add rows + recipes immediately so coverage never regresses.
