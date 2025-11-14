---
summary: 'Heuristics for filtering CG windows before screenshotting'
read_when:
  - 'touching ImageCommand/SeeCommand window selection logic'
  - 'plumbing CGWindow metadata into ServiceWindowInfo'
  - 'debugging why peekaboo image skips or captures overlays'
---

# Window Screenshot "Smart Select" Guide

Peekaboo’s screenshot tooling (`peekaboo image`, `see`, agent capture flows) must avoid the long tail of junk windows returned by CoreGraphics. This document explains how we map `CGWindow` metadata into `ServiceWindowInfo` and the heuristics every caller should apply before attempting a capture.

## 1. Metadata We Need

| Source | Key | Purpose |
| --- | --- | --- |
| `CGWindowListCopyWindowInfo` | `kCGWindowNumber` | Stable `CGWindowID` for cross-referencing and duplicate suppression. |
| `kCGWindowLayer` | Layer filtering (layer 0 = normal app windows). |
| `kCGWindowAlpha` | Skip fully transparent/hidden overlays. |
| `kCGWindowBounds` | Size thresholds + dedupe by area. |
| `kCGWindowIsOnscreen` | Detect off-screen windows when `.optionOnScreenOnly` isn’t in use. |
| `kCGWindowOwnerPID` / `Name` | Tie back to AX/Process info; drop background helpers. |
| `kCGWindowSharingState` | Respect `NSWindow.sharingType == .none` (system replaces pixels with a “bubble”). |
| `SCWindow` (`ScreenCaptureKit`) | `frame`, `isOnScreen`, `layer`, `sharingType`, `alpha`. |
| `NSWindow` (our own process) | `isExcludedFromWindowsMenu` so we never export intentionally hidden internal windows. |

`ServiceWindowInfo` should store these fields (or derived booleans like `isShareable`) so every CLI/agent feature can make the same decision.

## 2. Filtering Heuristics

Apply these checks in order; the first failure removes the candidate window:

1. **Layer:** require `layer == 0` (normal app chrome). Panels, menu bar extras, HUD bubbles use other layers and should be ignored unless specifically requested.
2. **Transparency:** skip if `alpha <= 0.01` — CG tells us the app doesn’t intend this surface to be visible.
3. **Sharing state:** `kCGWindowSharingState == kCGWindowSharingNone` (or `SCWindow.sharingType == .none`) means “don’t capture.” Bail early and surface a helpful error.
4. **Visibility:** require either `.optionOnScreenOnly` or `kCGWindowIsOnscreen == true`. Off-screen or minimized windows produce stale frames.
5. **Dimensions:** default threshold `width >= 120` and `height >= 90`. This filters tooltips, 1 px borders, rainbow bubbles, etc. Adjust per product needs but keep a floor.
6. **Title fallback:** prefer non-empty titles. If an app has multiple windows, accept one empty-titled window only when it is the sole candidate after the prior filters.
7. **Owner policy:** for `NSWindow`s we own, also skip `isExcludedFromWindowsMenu == true` unless a developer explicitly opts into exporting that surface.

Wrap this logic in a helper (e.g. `WindowFiltering.isRenderable(_ info: ServiceWindowInfo)`) so every command reuses the same rules.

## 3. Duplicate Handling

`CGWindowListCopyWindowInfo` frequently reports multiple entries per “real” window (tab bars, separators, compositing layers). To avoid double-counting:

1. Group entries by `kCGWindowNumber`.
2. Within each group, prefer the entry that is on-screen and has the largest bounding box.
3. Apply the heuristics above to the winner only.

This matches Chromium/WebRTC’s strategy (`only_zero_layer` filter) and keeps the noise floor low.

## 4. Capture Pipeline Integration

Every capture path should call the filter before touching ScreenCaptureKit/CGWindowList:

- `ImageCommand` / `SeeCommand`: when resolving a target window, skip disqualified entries and throw `PeekabooError.windowNotFound` if none remain. For `--mode multi`, silently drop bad windows instead of aborting the batch.
- `ScreenCaptureService`: if the selected `ServiceWindowInfo` is not shareable, exit before invoking SK/CG. This prevents rainbow bubbles and makes failures explicit.
- `WindowCommand list`: hide disqualified windows (or mark them as “hidden by app”) so agents don’t pick surfaces they can’t capture.

## 5. Testing Strategy

1. **Unit tests** for the filter helper, covering layer, alpha, sharing state, size, and visibility.
2. **Service tests** that feed canned CG dictionaries into `ApplicationService` / `ApplicationServiceWindowsWorkaround` to confirm metadata is preserved.
3. **CLI tests** (`InProcessCommandRunner`) ensuring `peekaboo image` errors when only hidden windows exist, and succeeds when a shareable window is available.

Keep fixtures small (two windows per app) so we can reason about why each candidate passes or fails the heuristic chain.
