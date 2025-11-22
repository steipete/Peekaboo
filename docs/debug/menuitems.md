# Menu Bar Item Debug Log (macOS 26.1, Trimmy missing)

Goal: Find why `peekaboo menubar list` does not show Trimmy on macOS 26.1 even though the status item is visible.

Timeline
- 2025-11-22 (earlier): Layer/AX heuristics showed only Control Center items. Trimmy absent.
- 2025-11-22: Added CGS menuBarItems bridge (dlopen CGSCopyWindowsWithOptions) + AX flatten + metadata fields (axIdentifier/axDescription). CGS reports 22 items; list shows WindowServer + ControlCenter + NotificationCenter only. Trimmy still absent.

Findings
- CGS menuBarItems returns only system/ControlCenter items in this process (22 IDs). No third-party status items.
- CGWindowList (layers 24/25) likewise shows only Control Center windows; Trimmy PID has no windows.
- AX scrape of Control Center/SystemUIServer yields placeholders, no Trimmy identifier.

Hypotheses
- CGS hides third-party status items from non-privileged callers on macOS 26.1 (or requires different options/entitlements).
- Trimmy’s NSStatusItem is rehosted inside Control Center without an exposed CGS window or AX identifier.

Planned next steps (no Vision fallback):
1) Add raw-debug output to `menubar list` (JSON flag) dumping windowID/owner PID/bundle/layer/title from CGS and CGWindowList, so we can prove whether Trimmy is returned but unlabeled, or missing entirely.
2) Add all-app AX sweep: traverse AX trees of all running apps, collect AXMenuBarItem/AXGroup descendants with non-placeholder title or identifier; merge into list as `source:"ax-app"` so Trimmy can surface even if CGS omits it.
3) Re-run `menubar list --json-output` with debug flag and log results here.

Environment
- macOS 26.1 arm64
- Peekaboo CLI built via `./scripts/build-cli-standalone.sh`
- Permissions: Screen Recording + Accessibility granted
- Trimmy running from `.build/debug/Trimmy`

Current output snapshot (post-CGS bridge):
- 22 items: Menubar (WindowServer), Notification Center, Control Center items (`com.apple.menuextra.wifi/clock/audiovideo/controlcenter` etc.). No Trimmy.

Needed to unblock Trimmy
- Implement steps 1–2 above and re-test.
