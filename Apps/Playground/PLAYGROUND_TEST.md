# Playground Tool Test Log

## 2025-11-16

### ⚠️ `see` command – Playground capture failing
- **Command**: `polter peekaboo -- see --app Playground --path .artifacts/playground-tools/20251116-074900-see.png --json-output`
- **Artifacts**: `.artifacts/playground-tools/20251116-074900-see.json`
- **Result**: Fails with `INTERNAL_SWIFT_ERROR` (“Failed to start stream due to audio/video capture failure”) because the window enumerator only finds a 64×64 stub window for Playground (see `.artifacts/playground-tools/20251116-075220-window-list-playground.json`). Need to ensure Playground.app presents a capture-sized window (launch via Xcode and bring to front) before rerunning `see`.
- **Attempts**: Tried launching `.derived-data/Playground/Build/Products/Debug/Playground.app` and resizing via AppleScript (`osascript` set window 1 size/position), but `window list` still reports a single 64×64 window, so `see` continues to fail. Follow-up required on the Playground app or capture service to make a full-size window available.

### ✅ `see` command – ScreenCaptureKit fallback restored
- **Command**: `polter peekaboo -- see --app Playground --json-output --path .artifacts/playground-tools/20251116-082056-see-playground.png`
- **Artifacts**: `.artifacts/playground-tools/20251116-082056-see-playground.{json,png}`
- **Result**: Successfully recorded session `5B5A2C09-4F4C-4893-B096-C7B4EB38E614` (301 UI elements). Screenshot shows ClickTestingView at full size; CLI debug logs still mention helper windows that are filtered out.
- **Notes**: Fix involved re-enabling the ScreenCaptureKit window path in `Core/PeekabooCore/Sources/PeekabooAutomation/Services/Capture/ScreenCaptureService.swift` so CGWindowList becomes the fallback instead of the primary path. Audio/video capture failures have not reproduced since the change.

### ✅ `image` command – Window + screen captures
- **Command(s)**:
  - `polter peekaboo -- image --app Playground --mode window --path .artifacts/playground-tools/20251116-045847-image-window-playground.png`
  - `polter peekaboo -- image --mode screen --screen-index 0 --path .artifacts/playground-tools/20251116-045900-image-screen0.png`
- **Artifacts**: `.artifacts/playground-tools/20251116-045847-image-window-playground.png`, `.artifacts/playground-tools/20251116-045900-image-screen0.png`
- **Verification**: Window capture shows ClickTestingView controls with sharp text; screen capture shows the entire desktop including Playground window on Space 1. CLI output confirms saved paths; no analyzer prompt used.
- **Notes**: Captures completed in <1s each; no focus issues observed while Playground remained frontmost.

### ✅ `image` command – window + screen capture after fallback fix
- **Command(s)**:
  - `polter peekaboo -- image window --app Playground --json-output --path .artifacts/playground-tools/20251116-082109-image-window-playground.png`
  - `polter peekaboo -- image screen --screen-index 0 --json-output --path .artifacts/playground-tools/20251116-082125-image-screen0.png`
- **Artifacts**: `.artifacts/playground-tools/20251116-082109-image-window-playground.{json,png}`, `.artifacts/playground-tools/20251116-082125-image-screen0.{json,png}`
- **Verification**: Both commands succeed after the ScreenCaptureKit-first change; debug logs report the helper “window too small” entries but the main Playground window captures at 1200×852 and the screen snapshot matches desktop state.
- **Notes**: These runs double-confirm that the capture fix benefits `image` as well as `see`; Playground logs contain `[Window] image window Playground` + `[Window] image screen frontmost` from `AutomationEventLogger`.

### ✅ `scroll` command – ScrollTestingView vertical + horizontal
- **Setup**: Switched to Scroll & Gestures tab via the new shortcut (`polter peekaboo -- hotkey --keys "cmd,option,4"`), then captured `.artifacts/playground-tools/20251116-085714-see-scrolltab.{json,png}` (session `DBFDD053-4513-4603-B7C3-9170E7386BA7`).
- **Commands**:
  1. `polter peekaboo -- scroll --session DBFDD053-… --direction down --amount 6`
  2. `polter peekaboo -- scroll --session DBFDD053-… --direction right --amount 4 --smooth`
  3. Negative: `polter peekaboo -- scroll --session DBFDD053-… --direction down --amount 2 --on vertical-scroll` (expected failure because the identifier isn’t exposed in `see`).
- **Artifacts**: `.artifacts/playground-tools/20251116-085815-scroll.log` shows the `[Scroll]` log lines for both successful commands; the error case prints “Element not found: vertical-scroll” to the CLI for documentation.
- **Notes**: ScrollTestingView still doesn’t surface `vertical-scroll` / `horizontal-scroll` IDs in the UI map, so `--on` remains unavailable. Use pointer-relative scrolls until those identifiers are exposed.

### ✅ `drag` command – DragDropView covered via element IDs
- **Setup**:
  - Added `PlaygroundTabRouter` as an environment object plus a header “Go to Drag & Drop” control so the UI mirrors the underlying tab selection.
  - `see` output always includes the “Drag & Drop” tab radio button (elem_79). Running `polter peekaboo -- click --session <see-id> --on elem_79` reliably switches the TabView to DragDropView, yielding IDs such as `elem_15` (“Item A”) and `elem_24` (“Drop here”).
- **Commands**:
  1. `polter peekaboo -- click --session BBF9D6B9-26CB-4370-8460-6C8188E7466C --on elem_79`
  2. `polter peekaboo -- drag --session BBF9D6B9-26CB-4370-8460-6C8188E7466C --from elem_15 --to elem_24 --duration 800 --steps 40`
  3. `polter peekaboo -- drag --session BBF9D6B9-26CB-4370-8460-6C8188E7466C --from elem_17 --to elem_26 --duration 900 --steps 45 --json-output`
- **Artifacts**:
  - `.artifacts/playground-tools/20251116-085142-see-afterclick-elem79.{json,png}` (Drag tab `see` output with identifiers)
  - `.artifacts/playground-tools/20251116-085233-drag.log` (Playground + CLI Drag OSLog entries)
  - `.artifacts/playground-tools/20251116-085346-drag-elem17.json` (CLI drag result with coords/profile)
- **Verification**: Playground log shows “Started dragging: Item A”, “Hovering over zone1”, and “Item dropped… zone1” for the first run, and the CLI JSON confirms the second run’s coordinates/profile. Post-drag screenshots display Item A/B inside their target drop zones. Coordinate-only drags remain as a fallback, but the default regression loop now uses element IDs + session IDs for determinism.

### ✅ `list` command suite – apps/windows/screens/menubar/permissions
- **Command(s)**: captured `list apps`, `list windows --app Playground`, `list screens`, `list menubar`, `list permissions` (all with `--json-output`)
- **Artifacts**:
  - `.artifacts/playground-tools/20251116-045915-list-apps.json`
  - `.artifacts/playground-tools/20251116-045919-list-windows-playground.json`
  - `.artifacts/playground-tools/20251116-045931-list-screens.json`
  - `.artifacts/playground-tools/20251116-045933-list-menubar.json`
  - `.artifacts/playground-tools/20251116-045936-list-permissions.json`
- **Verification**: Playground identified as bundle `boo.peekaboo.mac.debug` with six windows; menubar payload includes Wi-Fi and Clock items; permissions report Accessibility + Screen Recording both granted.
- **Notes**: Each command completed <3s. No additional log capture necessary; JSON artifacts are sufficient evidence.

### ✅ `tools` command – native + MCP catalog
- **Command(s)**:
  - `polter peekaboo -- tools --native-only --json-output > .artifacts/playground-tools/20251116-142009-tools-native.json`
  - `polter peekaboo -- tools --mcp-only --group-by-server > .artifacts/playground-tools/20251116-142009-tools-mcp.txt`
- **Verification**: Native JSON enumerates all built-in tools referenced in docs; MCP output remains empty (no remote servers enabled), which matches CLI expectations.
- **Notes**: No Playground interaction needed; artifacts captured for comparison when new tools land.

### ✅ `run` command – playground-smoke script
- **Script**: `docs/testing/fixtures/playground-smoke.peekaboo.json` (focus Playground, run `see`, click "Focus Basic Field", type "Playground smoke")
- **Prep**: Make sure Playground is on TextInputView before running—use `see` and `click --on <text-input-tab-id>` if another tab is active.
- **Command**: `polter peekaboo -- run docs/testing/fixtures/playground-smoke.peekaboo.json --output .artifacts/playground-tools/20251116-142711-run-playground.json --json-output`
- **Artifacts**: `.artifacts/playground-tools/20251116-142711-run-playground.json`, `.artifacts/playground-tools/run-script-see.png`
- **Verification**: Execution report shows 4/4 steps succeeded in 2.3 s, `see` step produced session `1763303232278-2419`; Playground UI updated (basic field text cleared + replaced).
- **Notes**: Script parameters must use the enum coding format (`{"generic":{"_0":{...}}}`) so ProcessService can normalize them. If you forget to switch tabs, step 3 fails with “Element not found: Focus Basic Field”.

### ✅ `sleep` command – timing verification
- **Command**: `python - <<'PY' … subprocess.run(["./runner","polter","peekaboo","--","sleep","2000"]) …` (see shell history)
- **Result**: CLI reported `✅ Paused for 2.0s`; wrapper measured ≈2.24 s wall-clock, matching expectation.
- **Notes**: No Playground interaction required; documented timing in `docs/testing/tools.md` under the `sleep` recipe.

### ✅ `clean` command – session pruning
- **Commands**:
  1. `polter peekaboo -- see --app Playground --path .artifacts/playground-tools/20251116-0506-clean-see1.png --annotate --json-output` → session `5408D893-E9CF-4A79-9B9B-D025BF9C80BE`
  2. `polter peekaboo -- see --app Playground --path .artifacts/playground-tools/20251116-0506-clean-see2.png --annotate --json-output` → session `129101F5-26C9-4A25-A6CB-AE84039CAB04`
  3. `polter peekaboo -- clean --session 5408D893-E9CF-4A79-9B9B-D025BF9C80BE`
  4. `polter peekaboo -- clean --session 5408D893-E9CF-4A79-9B9B-D025BF9C80BE` (expect 0 removals)
- **Verification**: First clean freed 453 KB and removed the session directory; second clean confirmed nothing left to delete. Attempting `click --session 5408D893-…` afterward yields a generic element-not-found error rather than “session missing” (possible UX improvement noted in docs).
- **Artifacts**: `.artifacts/playground-tools/20251116-050631-clean-see1{,_annotated}.png`, `.artifacts/playground-tools/20251116-050649-clean-see2{,_annotated}.png`, and CLI outputs in shell history.

### ✅ `permissions` command – status snapshot
- **Command**: `polter peekaboo -- permissions status --json-output > .artifacts/playground-tools/20251116-051000-permissions-status.json`
- **Verification**: JSON shows Screen Recording (required) + Accessibility (optional) both granted; no remedial steps needed.
- **Notes**: No Playground UI change expected; just keep the artifact for future reference.

### ✅ `config` command – show/validate
- **Commands**:
  - `polter peekaboo -- config show --effective --json-output > .artifacts/playground-tools/20251116-051200-config-show-effective.json`
  - `polter peekaboo -- config validate`
- **Verification**: Config reports OpenAI key present (masked), providers list `anthropic/claude-sonnet-4-5-20250929` + `ollama/llava:latest`, defaults/logging sections intact. Validation succeeded with all sections checked.
- **Notes**: No Playground interaction required.

### ✅ `learn` command – agent guide dump
- **Command**: `polter peekaboo -- learn > .artifacts/playground-tools/20251116-051300-learn.txt`
- **Verification**: File contains the full agent prompt, tool catalog, and commit metadata matching current build; no runtime errors.
- **Notes**: Useful baseline for future diffs when system prompt changes.

### ✅ `click` command – Playground targeting
- **Preparation**: Logged clicks via `.artifacts/playground-tools/20251116-051025-click.log`; captured fresh session `263F8CD6-E809-4AC6-A7B3-604704095011` (`.artifacts/playground-tools/20251116-051120-click-see.{json,png}`) after focusing Playground.
- **Commands**:
  1. `polter peekaboo -- click "Single Click" --session BE9FF9B6-…` (hit Ghostty due to focus loss) → reminder to focus Playground first.
  2. `polter peekaboo -- app switch --to Playground`
  3. `polter peekaboo -- click --on elem_6 --session 263F8CD6-…` (clicked View Logs button)
  4. `polter peekaboo -- click --coords 600,500 --session 263F8CD6-…`
  5. `polter peekaboo -- click --on elem_disabled --session 263F8CD6-…` (expected elementNotFound error)
- **Verification**: Playground log file shows the clicks (e.g., `[Click] single click on _SystemTextFieldFieldEditor ...`); disabled-ID click produced the expected error prompt.
- **Notes**: Legacy `B1` IDs no longer match; rely on `elem_*` IDs from current `see` output. Always re-focus Playground before coordinate clicks to avoid hitting other apps.

### ✅ `type` command – TextInputView coverage
- **Logs**: `.artifacts/playground-tools/20251116-051202-text.log`
- **Session**: `263F8CD6-E809-4AC6-A7B3-604704095011` from `.artifacts/playground-tools/20251116-051120-click-see.json`
- **Commands**:
  1. `polter peekaboo -- click "Focus Basic Field" --session 263F8CD6-…`
  2. `polter peekaboo -- type "Hello Playground" --clear --session 263F8CD6-…`
  3. `polter peekaboo -- type --tab 1 --session 263F8CD6-…`
  4. `polter peekaboo -- type "42" --session 263F8CD6-…`
  5. `polter peekaboo -- type "bad" --profile warp` (validation error)
- **Verification**: Logs show “Basic text changed…” and numeric field entries; tab-only command shifted focus before typing digits. Validation rejected invalid profile value as expected.
- **Notes**: Type command relies on focused element; helper button keeps tests deterministic.

### ✅ `press` command – key sequence testing
- **Logs**: `.artifacts/playground-tools/20251116-090455-keyboard.log`
- **Session**: `C106D508-930C-4996-A4F4-A50E2E0BA91A` (`.artifacts/playground-tools/20251116-090141-see-keyboardtab.{json,png}`)
- **Commands**:
  1. `polter peekaboo -- click "Focus Basic Field" --session 11227301-…`
  2. `polter peekaboo -- press return --session 11227301-…`
  3. `polter peekaboo -- press up --count 3 --session 11227301-…`
  4. `polter peekaboo -- press foo` (now errors with `Unknown key: 'foo'`)
- **Verification**: Return + arrow presses show up in Playground logs (Key pressed: Return / Up Arrow). Invalid tokens now fail fast thanks to a validation call at runtime; continue watching for any other unmapped keys.

### ⚠️ `menu` command – top-level and nested items
- **Logs**: `.artifacts/playground-tools/20251116-073145-menu.log`
- **Commands**:
  1. `polter peekaboo -- menu click --path "Test Menu>Test Action 1" --app Playground`
  2. `polter peekaboo -- menu click --path "Test Menu>Submenu>Nested Action A" --app Playground`
  3. `polter peekaboo -- menu click --path "Test Menu>Disabled Action" --app Playground`
- **Verification**: Menu log shows clicks for enabled actions, and disabled entries now error with `Menu item is disabled: …` thanks to the new preflight validation.
- **Next**: Extend coverage to context menu coordinates and ensure disabled submenu entries in other apps trigger the same error path.

### ✅ `hotkey` command – modifier combos
- **Logs**: `.artifacts/playground-tools/20251116-051654-keyboard-hotkey.log`
- **Session**: `11227301-05DE-4540-8BE7-617F99A74156`
- **Commands**:
  1. `polter peekaboo -- hotkey --keys "cmd,shift,l" --session 11227301-...`
  2. `polter peekaboo -- hotkey --keys "cmd,1" --session 11227301-...`
  3. `polter peekaboo -- hotkey --keys "foo,bar"`
- **Verification**: Keyboard logs show the expected characters (L/1) with timestamps matching the commands. Invalid combo correctly errors with `Unknown key: 'foo'`.

### ⚠️ `scroll` command – logs now emitted
- **Logs**: `.artifacts/playground-tools/20251116-073820-scroll.log`
- **Commands**:
  1. `polter peekaboo -- see --app Playground --json-output` → session `263F8CD6-832E-4E1C-98CC-2A2F6D5C67C7`
  2. `polter peekaboo -- scroll --direction down --amount 5 --session 263F8CD6-…`
- **Findings**:
  - ScrollTestingView now logs offsets via the new ScrollOffsetReader helper, so the Scroll log category shows entries even when the CLI performs the scroll.
  - Accessibility identifiers like `vertical-scroll` exist in the view hierarchy, but `see` output still doesn’t surface them—need to investigate AX export so `--on` works without coordinates.

### ⚠️ `swipe` command – gesture log missing
- **Logs**: `.artifacts/playground-tools/20251116-074000-gesture.log`
- **Commands**:
  1. `polter peekaboo -- swipe --from-coords 900,450 --to-coords 600,450 --duration 600`
  2. `polter peekaboo -- swipe --from-coords 700,600 --to-coords 700,350 --profile human --duration 800 --session 4644659E-B185-441D-8ED3-5D5FC8976833`
  3. `polter peekaboo -- swipe --from-coords 600,600 --to-coords 600,400 --right-button` (expected error)
- **Findings**: Gesture log now records synthetic swipes (albeit privacy-redacted in Console). Need follow-up to add more descriptive log messages (direction/distance) inside GestureArea to make analysis easier.

### ⚠️ `drag` command – cannot reach DragDropView via automation
- **Logs**: `.artifacts/playground-tools/20251116-074430-drag.log`
- **Commands**:
  1. `polter peekaboo -- see --app Playground --json-output` (still fails with `Failed to start stream due to audio/video capture failure`; capture phase reports only “window too small” / `layer != 0` windows even after launching `.derived-data/.../Playground.app`)
  2. `polter peekaboo -- click "Drag & Drop" --session …` → `elementNotFound`
  3. `polter peekaboo -- drag --from-coords 500,500 --to-coords 700,700 --duration 800`
- **Findings**:
  - DragDropView now exposes identifiers (`drag-drop-header`, `drag-drop-items`, `drop-zones`, `free-drag-area`, `draggable-1`, etc.), but we can’t surface them until `see` captures Playground’s window.
  - Coordinate drags succeed and the Drag OSLog category records the action (`.artifacts/...074430-drag.log`).
  - Next: debug the capture failure (likely a screen-recording fall-back bug) so `see` yields the Drag tab, then reattempt `--from/--to` ID drags.

### ⚠️ `move` command – cursor logs missing
- **Logs**: `.artifacts/playground-tools/20251116-074500-focus.log`
- **Commands**:
  1. `polter peekaboo -- move 600,600`
  2. `polter peekaboo -- move --to "Focus Basic Field" --session B1F9128C-0007-4D14-930E-C9D70C1D779F --smooth`
  3. `polter peekaboo -- move --center --duration 300 --steps 15`
- **Findings**: Focus log now records entries (both from Playground UI and the CLI move command). The CLI entry still shows `<private>` in Console, so add more descriptive strings if we need richer auditing.

### ⚠️ `window` command – logs captured via TextEdit run
- **Logs**: `.artifacts/playground-tools/20251116-073620-window.log`
- **Artifacts**: `.artifacts/playground-tools/20251116-073500-window-list-textedit.json`
- **Commands**:
  1. `polter peekaboo -- window list --app TextEdit --json-output`
  2. `polter peekaboo -- window focus --app TextEdit`
  3. `polter peekaboo -- window move --app TextEdit --x 200 --y 200`
  4. `polter peekaboo -- window resize --app TextEdit --width 800 --height 500`
  5. `polter peekaboo -- window set-bounds --app TextEdit --x 150 --y 150 --width 700 --height 400`
- **Findings**: After wiring logWindowAction into focus/move/resize/set-bounds, the Window log now records each action (privacy redacted). Need to port the same instrumentation to Drag/Move commands in Playground UI so both app + CLI produce entries.

### ⚠️ `app` command – instrumentation logging actions
- **Logs**: `.artifacts/playground-tools/20251116-071820-app.log`
- **Artifacts**: `.artifacts/playground-tools/20251116-071500-app-list.json`, `.artifacts/playground-tools/20251116-071540-app-launch-textedit.json`, `.artifacts/playground-tools/20251116-071548-app-quit-textedit.json`
- **Commands**:
  1. `polter peekaboo -- app list --include-hidden --json-output`
  2. `polter peekaboo -- app hide --app Playground` / `app unhide --app Playground --activate`
  3. `polter peekaboo -- app launch "TextEdit" --json-output`
  4. `polter peekaboo -- app quit --app TextEdit --json-output`
  5. `polter peekaboo -- app switch --to Playground`
- **Findings**: `AutomationEventLogger` now emits App entries for launch/hide/unhide/quit/switch with bundle IDs + PIDs. Need to extend coverage to relaunch/list edge cases later, but the missing-log blocker is resolved.

### ⚠️ `space` command – single-space setup, no logs
- **Logs**: `.artifacts/playground-tools/20251116-075405-space.log` (empty)
- **Artifacts**: `.artifacts/playground-tools/20251116-075400-space-list.json`, `...-075402-space-list-detailed.json`
- **Commands**:
  1. `polter peekaboo -- space list --json-output`
  2. `polter peekaboo -- space list --detailed --json-output`
  3. `polter peekaboo -- space switch --to 1` (OK), `--to 2` (fails with “Available: 1-1”)
  4. `polter peekaboo -- space move-window --app Playground --to 1 --follow`
- **Findings**: Only one Space currently exists; multi-space scenarios blocked until another Space is created. Space log doesn’t emit entries for list/switch/move operations—needs instrumentation.

### ✅ `menubar` command – Wi-Fi + Control Center
- **Artifacts**: `.artifacts/playground-tools/20251116-141824-menubar-list.json`
- **Commands**:
  1. `polter peekaboo -- menubar list --json-output`
  2. `polter peekaboo -- menubar click "Wi-Fi"`
  3. `polter peekaboo -- menubar click --index 2`
- **Notes**: CLI output confirms the clicked items (Wi-Fi by title, Control Center by index). Still no dedicated menubar logger—`playground-log.sh -c Menu` remains empty for these operations, so rely on CLI artifacts for evidence.

- ### ✅ `open` command – Open logger emits entries
- **Logs**: `.artifacts/playground-tools/20251116-081005-open.log`
- **Artifacts**: `.artifacts/playground-tools/20251116-071730-open-textedit-readme.json`, `.artifacts/playground-tools/20251116-081000-open-example.json`
- **Commands**:
  1. `polter peekaboo -- open Apps/Playground/README.md --app TextEdit --json-output`
  2. `polter peekaboo -- open https://example.com --json-output`
  3. `polter peekaboo -- open Apps/Playground/README.md --app TextEdit --no-focus`
- **Findings**: Open log now records local files (TextEdit) and URL handlers (Chrome) with focus state; additional wait-until-ready scenarios can be added later if needed.

### ⚠️ `dock` command – Dock logger working
- **Logs**: `.artifacts/playground-tools/20251116-081210-dock.log`
- **Artifacts**: `.artifacts/playground-tools/20251116-081200-dock-list.json`
- **Commands**:
  1. `polter peekaboo -- dock list --json-output`
  2. `polter peekaboo -- dock right-click --app Finder`
- **Findings**: Dock log captures list/right-click entries; selecting specific context menu items still fails (“Menu not found…”), so follow-up needed if we care about picking actions after the right-click.

### ✅ `dialog` command – TextEdit Save sheet
- **Logs**: `.artifacts/playground-tools/20251116-080435-dialog.log`
- **Artifacts**: `.artifacts/playground-tools/20251116-080430-dialog-list.json`
- **Commands**:
  1. `polter peekaboo -- dialog list --app TextEdit --json-output`
  2. `polter peekaboo -- dialog click --button "Cancel" --app TextEdit`
- **Outcome**: After launching TextEdit, creating a new document, running `see` for the session, and sending `cmd+s`, both `dialog list` and `dialog click` succeed and emit `[Dialog]` log entries for evidence.

### ✅ `agent` command – logs emitted by CLI
- **Logs**: `.artifacts/playground-tools/20251116-075955-agent.log`
- **Artifacts**: `.artifacts/playground-tools/20251116-075700-agent-list.json`, `...075705-agent-hi.json`, `...075716-agent-toolbar.json`
- **Commands**:
  1. `polter peekaboo -- agent --list-sessions --json-output`
  2. `polter peekaboo -- agent "Summarize the TextEdit toolbar" --dry-run --max-steps 2`
  3. `polter peekaboo -- agent "Say hi" --max-steps 1`
- **Findings**: AutomationEventLogger now emits `[Agent]` entries summarizing each run (task, model, duration, tool calls, session ID), so `playground-log -c Agent` captures evidence even though Playground UI doesn’t log these events itself.

### ⚠️ `mcp` command – `call` now steadies but remote server unavailable
- **Logs**: `.artifacts/playground-tools/20251116-055255-mcp.log` (list) and `.artifacts/playground-tools/20251116-065820-mcp-call-chrome-devtools.log`
- **Artifacts**: `.artifacts/playground-tools/20251116-055255-mcp-list.json`
- **Commands**:
  1. `polter peekaboo -- mcp list --json-output`
  2. `polter peekaboo -- mcp call chrome-devtools list_tabs`
- **Findings**: Commander argument crash is fixed—the CLI now launches Tachikoma’s MCP client, attempts to connect to `chrome-devtools` via `npx`, and retries the `initialize` handshake three times before timing out (expected because the server isn’t running locally). Need a reachable MCP server/stub to capture a successful call artifact, but the blocker noted earlier is resolved.

### ✅ `dialog` command – TextEdit Save sheet
- **Commands**:
  1. `polter peekaboo -- app launch TextEdit`
  2. `polter peekaboo -- menu click --path "File>New" --app TextEdit`
  3. `SESSION=$(polter peekaboo -- see --app TextEdit --json-output | jq -r '.data.session_id')`
  4. `polter peekaboo -- hotkey --keys "cmd,s" --session $SESSION`
  5. `polter peekaboo -- dialog list --app TextEdit --json-output > .artifacts/playground-tools/20251116-054316-dialog-list.json`
  6. `polter peekaboo -- dialog click --button "Cancel" --app TextEdit`
- **Verification**: `dialog list` returns Save sheet metadata (buttons Cancel/Save, AXSheet role). Playground log remains empty, but JSON artifact confirms the dialog.
- **Notes**: ScrollTestingView still doesn’t surface `vertical-scroll` / `horizontal-scroll` IDs in the UI map, so `--on` remains unavailable. Use pointer-relative scrolls until those identifiers are exposed.

### ✅ `swipe` command – Gesture area coverage
- **Setup**: Stayed on the Scroll & Gestures tab/session from the scroll run (`DBFDD053-4513-4603-B7C3-9170E7386BA7`, artifacts `.artifacts/playground-tools/20251116-085714-see-scrolltab.{json,png}`).
- **Commands**:
  1. `polter peekaboo -- swipe --from-coords 1100,520 --to-coords 700,520 --duration 600`
  2. `polter peekaboo -- swipe --from-coords 850,600 --to-coords 850,350 --duration 800 --profile human`
  3. `polter peekaboo -- swipe --from-coords 900,520 --to-coords 700,520 --right-button` (expected failure)
- **Artifacts**: `.artifacts/playground-tools/20251116-090041-gesture.log` contains both successful swipes with direction/profile metadata; the negative command prints `Right-button swipe is not currently supported…` in the CLI output for documentation.
- **Notes**: Gesture logging is now wired via `AutomationEventLogger`, so future swipes should always leave `[Gesture]` entries without additional instrumentation.

### ✅ `press` command – Keyboard detection
- **Setup**: Switched to Keyboard tab via `polter peekaboo -- hotkey --keys "cmd,option,7"`, then ran `see` to capture `.artifacts/playground-tools/20251116-090141-see-keyboardtab.{json,png}` (session `C106D508-930C-4996-A4F4-A50E2E0BA91A`). Focused the “Press keys here…” field with `polter peekaboo -- click --session … --coords 760,300`.
- **Commands**:
  1. `polter peekaboo -- press return --session C106D508-…`
  2. `polter peekaboo -- press up --count 3 --session C106D508-…`
  3. `polter peekaboo -- press foo` (expected error)
- **Artifacts**: `.artifacts/playground-tools/20251116-090455-keyboard.log` shows the Return and repeated Up Arrow events (plus the earlier tab-switch log). The invalid command prints `Unknown key: 'foo'…`.
- **Notes**: The keyboard log proves the `press` command triggers the in-app detection view; negative test documents the current error surface for unsupported keys.

### ✅ `menu` command – Test Menu actions + disabled item
- **Setup**: With Playground frontmost, listed the menu hierarchy via `polter peekaboo -- menu list --app Playground --json-output > .artifacts/playground-tools/20251116-090600-menu-playground.json` to confirm Test Menu items exist.
- **Commands**:
  1. `polter peekaboo -- menu click --app Playground --path "Test Menu>Test Action 1"`
  2. `polter peekaboo -- menu click --app Playground --path "Test Menu>Submenu>Nested Action A"`
  3. `polter peekaboo -- menu click --app Playground --path "Test Menu>Disabled Action"` (expected failure)
- **Artifacts**: `.artifacts/playground-tools/20251116-090512-menu.log` contains the `[Menu]` log entries for the successful clicks. The failure case saved as `.artifacts/playground-tools/20251116-090509-menu-click-disabled.json` with `INTERACTION_FAILED` and the “Menu item is disabled…” message.
- **Notes**: `menu click` currently targets menu-bar items only; context menus in ClickTestingView still need `click`/`rightClick` coverage outside of the `menu` command.
- **Notes**: `menu click` currently targets menu-bar items only; context menus in ClickTestingView still need `click`/`rightClick` coverage outside of the `menu` command.

### ✅ `app` command – list/switch/hide/launch coverage
- **Setup**: With Playground active, ran `polter peekaboo -- app list --include-hidden --json-output > .artifacts/playground-tools/20251116-090750-app-list.json` and captured the app log (`.artifacts/playground-tools/20251116-090840-app.log`) via `playground-log.sh -c App`.
- **Commands**:
  1. `polter peekaboo -- app switch --to Playground`
  2. `polter peekaboo -- app hide --app Playground` / `polter peekaboo -- app unhide --app Playground`
  3. `polter peekaboo -- app launch "TextEdit" --json-output > .artifacts/playground-tools/20251116-090831-app-launch-textedit.json`
  4. `polter peekaboo -- app quit --app TextEdit --json-output > .artifacts/playground-tools/20251116-090837-app-quit-textedit.json`
- **Result**: All commands succeeded; `.artifacts/playground-tools/20251116-090840-app.log` shows `list`, `switch`, `hide`, `unhide`, `launch`, and `quit` entries with bundle IDs and PIDs. No anomalies observed—`hide` does not auto-activate afterward (matching CLI messaging).
- **Result**: All commands succeeded; `.artifacts/playground-tools/20251116-090840-app.log` shows `list`, `switch`, `hide`, `unhide`, `launch`, and `quit` entries with bundle IDs and PIDs. No anomalies observed—`hide` does not auto-activate afterward (matching CLI messaging).

### ✅ `dock` command – list/launch/hide/show/right-click
- **Setup**: Ran `polter peekaboo -- dock list --json-output > .artifacts/playground-tools/20251116-090944-dock-list.json` to snapshot Dock items, then tailed Dock logs via `playground-log.sh -c Dock`.
- **Commands**:
  1. `polter peekaboo -- dock launch Playground`
  2. `polter peekaboo -- dock hide` and `polter peekaboo -- dock show`
  3. `polter peekaboo -- dock right-click --app Finder --select "New Finder Window" --json-output > .artifacts/playground-tools/20251116-091016-dock-right-click.json`
- **Artifacts**: `.artifacts/playground-tools/20251116-091019-dock.log` contains the `list`, `launch`, `hide`, `show`, and `right_click` entries with metadata. The right-click JSON confirms `selectedItem: "New Finder Window"`.
- **Notes**: Dock automation is now fully traceable via `AutomationEventLogger`; future regression runs can rely on the `dock log` output to validate behaviors.

### ✅ `open` command – TextEdit + browser targets
- **Commands**:
  1. `polter peekaboo -- open Apps/Playground/README.md --app TextEdit --json-output > .artifacts/playground-tools/20251116-091415-open-readme-textedit.json`
  2. `polter peekaboo -- open https://example.com --json-output > .artifacts/playground-tools/20251116-091422-open-example.json`
  3. `polter peekaboo -- open Apps/Playground/README.md --app TextEdit --no-focus --json-output > .artifacts/playground-tools/20251116-091435-open-readme-textedit-nofocus.json`
- **Verification**: `.artifacts/playground-tools/20251116-091445-open-open.log` shows the corresponding `[Open]` entries (TextEdit focused, Chrome focused, TextEdit focused=false). After the tests, `polter peekaboo -- app quit --app TextEdit` cleaned up the extra window.

### ✅ `space` command – list/switch/move-window
- **Commands**:
  1. `polter peekaboo -- space list --detailed --json-output > .artifacts/playground-tools/20251116-091557-space-list.json`
  2. `polter peekaboo -- space switch --to 1`
  3. `polter peekaboo -- space switch --to 2 --json-output > .artifacts/playground-tools/20251116-091602-space-switch-2.json` (expected failure; only one space exists)
  4. `polter peekaboo -- space move-window --app Playground --to 1 --follow`
- **Result**: All commands behaved as expected—Space enumerations still report a single desktop and the Space 2 attempt returns `VALIDATION_ERROR`. `playground-log.sh -c Space` continues to output empty logs (`.artifacts/playground-tools/20251116-091632-space.log`) because no dedicated Space logger exists yet.

### ✅ `agent` command – list + sample tasks
- **Commands**:
  1. `polter peekaboo -- agent --list-sessions --json-output > .artifacts/playground-tools/20251116-091814-agent-list.json`
  2. `polter peekaboo -- agent "Say hi" --max-steps 1 --json-output > .artifacts/playground-tools/20251116-091820-agent-hi.json`
  3. `polter peekaboo -- agent "Summarize the Playground UI" --dry-run --max-steps 2 --json-output > .artifacts/playground-tools/20251116-091831-agent-toolbar.json`
- **Verification**: `.artifacts/playground-tools/20251116-091839-agent.log` shows `[Agent]` entries for both tasks (model, duration, dry-run flag). Outputs confirm the CLI returns structured responses and respects `--dry-run` / `--max-steps`.

### ✅ `move` command – coordinates, targets, center
- **Commands**:
  1. `polter peekaboo -- move 600,600`
  2. `polter peekaboo -- move --to "Focus Basic Field" --session DBFDD053-4513-4603-B7C3-9170E7386BA7 --smooth`
  3. `polter peekaboo -- move --center --duration 300 --steps 15`
- **Result**: All three moves succeeded (CLI output shows target info, distances, and timing). Attempting `move --to-coords ...` or `--coords ...` still errors with “Unknown option …” because the command expects positional coordinates or `--to`; leaving that TODO in the docs.
- **Notes**: `playground-log -c Focus` remains empty during these runs, so CLI output is the primary evidence for now.

### ⏸️ `mcp` command – servers still unreachable
- **Commands**:
  1. `polter peekaboo -- mcp list --json-output > .artifacts/playground-tools/20251116-091934-mcp-list.json`
  2. `polter peekaboo -- mcp call chrome-devtools list_tabs --json-output > .artifacts/playground-tools/20251116-092025-mcp-call-chrome.json`
- **Result**:
  - `mcp list` succeeds after ~45s (no local MCP servers respond quickly, but the command eventually returns with an empty/default list).
  - `mcp call chrome-devtools list_tabs` fails: the stdio transport launches (`npx ...`), but the server never acknowledges `initialize`, so the client retries three times with different protocol fields and then times out. CLI logs show the entire retry sequence (see the artifact file).
- **Notes**: `playground-log.sh -c MCP` remains empty—there’s no Playground logging for MCP yet. To fully verify this tool we’ll need a reachable MCP server or a stubbed mock; current behavior is “graceful failure after handshake timeouts”.

### ✅ `dialog` command – TextEdit Save sheet
- **Setup**:
  1. `polter peekaboo -- app launch TextEdit --wait-until-ready --json-output > .artifacts/playground-tools/20251116-091212-textedit-launch.json`
  2. `polter peekaboo -- menu click --path "File>New" --app TextEdit`
  3. `polter peekaboo -- see --app TextEdit --json-output --path .artifacts/playground-tools/20251116-091229-see-textedit.png` (session `0485162B-6D02-4A72-9818-48C79452AEAC`)
  4. `polter peekaboo -- hotkey --keys "cmd,s" --session 0485162B-…`
- **Commands**:
  1. `polter peekaboo -- dialog list --app TextEdit --json-output > .artifacts/playground-tools/20251116-091255-dialog-list.json`
  2. `polter peekaboo -- dialog click --button "Cancel" --app TextEdit --json-output > .artifacts/playground-tools/20251116-091259-dialog-click-cancel.json`
- **Artifacts**: `.artifacts/playground-tools/20251116-091306-dialog.log` shows `[Dialog] action=list` and `action=click button='Cancel'` entries. JSON artifacts include the full dialog metadata and confirm the click result.
- **Notes**: Re-run the `hotkey --keys "cmd,s"` step whenever the dialog is dismissed so future dialog tests have a live window to interact with.
