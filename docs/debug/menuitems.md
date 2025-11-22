# Menu Bar Item Debug Log (macOS 26.1, Trimmy missing)

Goal: Find why `peekaboo menubar list` does not show Trimmy on macOS 26.1 even though the status item is visible.

Timeline
- 2025-11-22 (earlier): Layer/AX heuristics showed only Control Center items. Trimmy absent.
- 2025-11-22: Added CGS menuBarItems bridge (dlopen CGSCopyWindowsWithOptions) + AX flatten + metadata fields (axIdentifier/axDescription). CGS reports 22 items; list shows WindowServer + ControlCenter + NotificationCenter only. Trimmy still absent.
- 2025-11-22 (afternoon): Fixed `--include-raw-debug` flag plumbing; JSON now emits raw_window_id/layer/owner_pid/source.
- 2025-11-22 (afternoon): Added CGSProcessMenuBarWindowList fallback (SkyLight) + on-screen filtering. Combined CGS lists still only return Control Center + Notification Center windows.

Findings
- CGS menuBarItems returns only system/ControlCenter items in this process (19–22 IDs depending on union). No third-party status items.
- CGSProcessMenuBarWindowList + on-screen filter yields same set (Control Center + Notification Center).
- CGWindowList (layers 24/25) likewise shows only Control Center windows; Trimmy PID has no windows (`pgrep -fl Trimmy` -> 56004; CGWindowListCopyWindowInfo finds 0 windows for that PID).
- Control Center and SystemUIServer AX trees contain no strings matching “trim”.
- AX sweep of Trimmy shows only normal application menus (Apple / Trimmy / Edit / View / Window / Help) — no status item nodes with coordinates.
- Added all-app AX sweep (source `ax-app`) plus CGS active-space filtering + hit-test enrichment. Current output now surfaces Trimmy once (title “Trimmy”, source `ax-app`, raw_title “Cut”) while CGS still only shows Control Center/Notification Center windows.

Hypotheses
- CGS hides third-party status items from non-privileged callers on macOS 26.1 (or requires different options/entitlements).
- Trimmy’s NSStatusItem is rehosted inside Control Center without an exposed CGS window or AX identifier.

Planned next steps (no Vision fallback):
1) Tighten AX sweep to only status items (exclude app menu bar entries); use position/role/subrole heuristics to keep right-side extras and drop left-side app menus.
2) Correlate CGS window IDs with AX nodes (hit-test) to attach identifiers to Control Center “Item-0” windows.
3) Re-run `menubar list --json-output --include-raw-debug` and document whether Trimmy appears as a status item (not as app menu).

Environment
- macOS 26.1 arm64
- Peekaboo CLI built via `./scripts/build-cli-standalone.sh`
- Permissions: Screen Recording + Accessibility granted
- Trimmy running from `.build/debug/Trimmy`

Current output snapshot (post-CGS bridge):
- 22 items: Menubar (WindowServer), Notification Center, Control Center items (`com.apple.menuextra.wifi/clock/audiovideo/controlcenter` etc.). No Trimmy.

Needed to unblock Trimmy
- Implement steps 1–2 above and re-test.
