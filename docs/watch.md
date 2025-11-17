---
summary: 'Implementation plan for the `watch` smart-capture command (adaptive PNG bursts + contact sheet)'
read_when:
  - 'planning or implementing the watch command'
  - 'adding long-form, change-aware captures for agents'
  - 'aligning new capture parameters with existing CLI/MCP tooling'
---

# `watch` Command Implementation Plan

Goal: add a long-running, change-aware PNG capture tool (`peekaboo watch`) that watches a screen/window/region, emits only meaningful frames, and auto-builds a contact sheet so agents don’t sift through duplicates.

## Design Constraints (from existing tools)
- One-word verb name like `image`, `see`, `click`; files should mirror `ImageCommand.swift` patterns.
- Reuse existing parameter shapes/names where possible (`--mode`, `--screen-index`, `--app`, `--pid`, `--window-title`, `--window-index`, `--path`).
- Reuse `captureFocus` semantics from `ImageCommand` (`auto|background|foreground`) so window targets surface reliably.
- PNG-only output (no video). Contact sheet always generated.
- Scope accepts `screen:<id>`, `window:<id|frontmost>`, or `region:{x,y,w,h}` (region is new but matches `see --region` semantics if present).
- Agents view images only; JSON/metadata should call out timestamps, kept/dropped counts, motion intervals.

## UX & Defaults
- Flags (CLI):  
  - Targeting: `--mode screen|window|frontmost|region`, `--screen-index <n>`, `--app`, `--pid`, `--window-title`, `--window-index`, `--region "x,y,w,h"`, `--capture-focus auto|background|foreground`.  
  - Behavior: `--duration <seconds>` (default 60, max 180), `--idle-fps <float>` (default 2, min 0.1, max 5), `--active-fps <float>` (default 8, cap 15), `--threshold <percent>` (default 2.5, 0–100), `--heartbeat-sec <seconds>` (default 5, 0 disables), `--quiet-ms <ms>` (default 1000), `--highlight-changes` (bool off by default).  
  - Guardrails: `--max-frames <int>` (soft stop, default 800), optional `--max-mb <int>` (soft stop; ignored if unset). When a cap triggers, session ends early and records a warning.  
  - Output: `--path <dir>` (default temp), `--autoclean-minutes <int>` (default 120).
- MCP tool fields mirror flags in camelCase.
- Always keep first frame; heartbeat frames enforce slow-drift visibility.
- Resolution cap: downscale to max 1440p by default to control I/O; allow override later if needed.
- Mode resolution mirrors `ImageCommand.determineMode()`: explicit `--mode` wins; else if `app|pid|windowTitle` present → `.window`; else `.frontmost`.

## Capture Pipeline (Core)
1. **Scope resolution**: reuse `ApplicationResolvable` + existing screen/window lookup used by `ImageCommand`/`SeeCommand`; add `region` path. Regions are in global display coordinates (same as `services.screens`), HiDPI-aware; if a region spans displays, crop to the intersection. For screens, accept index and Display UUID; ensure metadata records chosen display.
2. **Frame source**: build on the same capture abstraction as `ImageCommand` (ScreenCapture service). Use `CGDisplayStream` for screens/regions where available; fallback paths share color space/permission handling with `image`. For window captures, reuse `screenCapture.captureWindow`; for region, crop post-capture in global display coords.
3. **Downscaled copy for diff**: produce ~256px-wide GRAY8 buffer to compute change metric; allow diff strategy selection (`fast` = abs-diff with motion box, `quality` = SSIM on downscaled luma with same bounding box). Record `diffAlgorithm` + `diffScale` in metadata; if strategy auto-downgrades, add warning.
4. **Mode switching (with hysteresis)**:
   - Idle cadence at `idle-fps`; Active cadence at `active-fps`.
   - Enter Active when `changePercent ≥ threshold`.
   - Exit to Idle when `changePercent < threshold/2` for ≥ `quiet-ms`.
   - Quiet timer resets on any frame with `changePercent ≥ threshold/2`.
   - Heartbeat: force-keep every `heartbeat-sec` even if idle.
   - If encode+diff costs outrun cadence, auto-reduce effective FPS and log in `warnings` + `fpsEffective`.
5. **Retention**: store kept `CGImage` → PNG via `CGImageDestination` to temp dir; deterministic names `frame-0001.png`.
6. **Highlighting (optional)**: if `--highlight-changes`, render motion bounding boxes onto kept frames before writing.
7. **Early stops**: if `max-frames` or `max-mb` (when supplied) is exceeded, stop capture, emit warning, finalize contact sheet/metadata.

## Outputs
- `frames`: PNG sequence with timestamps, changePercent, keep reason (`first|motion|heartbeat|cap`), and motion boxes when available.
- `contact.png`: auto grid (max 6 columns; rows inferred). Include contact metadata (cols/rows/thumb size, sampled frame indexes). For large frame counts, sample evenly across the sequence instead of placing every frame, and report the sampled indexes.
- `metadata.json`: structured schema (see below) including scope, options, stats, per-frame entries, motion intervals, warnings, diff algorithm/scale, autoclean time.
- CLI/MCP responses share the same `WatchCaptureResult` (see schema); text output mirrors `ImageCommand` log style.

### Schema (Swift-first)
```swift
struct WatchFrameInfo: Codable {
    enum Reason: String, Codable { case first, motion, heartbeat, cap }
    let index: Int
    let path: String          // absolute
    let file: String          // basename for metadata.json
    let timestampMs: Int
    let changePercent: Double
    let reason: Reason
    let motionBoxes: [CGRect]?
}

struct WatchMotionInterval: Codable {
    let startFrameIndex: Int
    let endFrameIndex: Int
    let startMs: Int
    let endMs: Int
    let maxChangePercent: Double
}

struct WatchStats: Codable {
    let durationMs: Int
    let fpsIdle: Double
    let fpsActive: Double
    let fpsEffective: Double
    let framesKept: Int
    let framesDropped: Int
    let maxFramesHit: Bool
    let maxMbHit: Bool
}

struct WatchScope: Codable {
    enum Kind: String, Codable { case screen, window, frontmost, region }
    let kind: Kind
    let screenIndex: Int?
    let displayUUID: String?
    let windowId: CGWindowID?
    let region: CGRect?
}

struct WatchContactSheet: Codable {
    let path: String
    let file: String
    let columns: Int
    let rows: Int
    let thumbSize: CGSize
    let sampledFrameIndexes: [Int]
}

struct WatchWarnings: Codable {
    enum Code: String, Codable {
        case noMotion, sizeCap, frameCap, windowClosed, displayChanged, lowFps, diffDowngraded
    }
    let code: Code
    let message: String
}

struct WatchCaptureResult: Codable {
    let frames: [WatchFrameInfo]
    let contactSheet: WatchContactSheet
    let metadataFile: String
    let stats: WatchStats
    let scope: WatchScope
    let diffAlgorithm: String
    let diffScale: String
    let options: WatchOptionsSnapshot // includes threshold, heartbeat, quietMs, mask regions etc.
    let warnings: [WatchWarnings]
}
```
`metadata.json` should mirror `WatchCaptureResult` but store `file` (basename) instead of absolute paths for portability; CLI/MCP return absolute paths in `frames.contactSheet.metadataFile`.

## Code Placement
- CLI: `Apps/CLI/Sources/PeekabooCLI/Commands/Core/WatchCommand.swift` + `WatchCommand+CommanderMetadata.swift` mirroring `ImageCommand` structure.
- Core capture logic: extend `PeekabooCore` (likely alongside `ScreenCapture` utilities) with a new `SmartCaptureSession` type managing the adaptive cadence, diffing, and contact sheet generation.
- Shared types: add `WatchCaptureOptions` and `WatchCaptureResult` to `PeekabooCore` for reuse by CLI and MCP surfaces.
- MCP exposure: add tool entry in `Apps/CLI/Sources/PeekabooCLI/Commands/MCP` parallel to existing tools, reusing the new core options.

## Technology Choices
- Capture: `CGDisplayStream` for screens/regions; existing window capture path via `CGWindowListCreateImage`/`screenCapture.captureWindow`.
- Diffing: SSIM/abs-diff on downscaled GRAY8 buffers; fallback to pHash if SSIM too slow.
- Encoding: `CGImageDestination` to PNG (UTType.png).
- Contact sheet: `CGContext` compositing thumbnails; write as PNG.
- Concurrency: API surfaces `@MainActor`; capture/diff/encode on dedicated serial BG queue to avoid UI stalls, respecting project concurrency guidance.

## Error Handling & Guardrails
- Require screen recording permission up front (reuse `requireScreenRecordingPermission`).
- Validate durations/fps caps; reject invalid mode/scope combos with clear errors consistent with existing commands.
- Ensure at least one frame is written; emit warning if no motion detected.
- Autoclean: store sessions under a managed temp root (`.../Peekaboo/watch-sessions/watch-<id>`). On each new session start, delete stale subdirs older than `autoclean-minutes`; skip cleanup if user supplies `--path` outside that root. Record `autocleanAt` in metadata.
- Handle mid-session target changes: stop with warning if window closes; if display configuration changes, crop to current bounds and add `displayChanged` warning; ensure metadata reflects the scope at stop time.

## Testing Plan
- Swift Testing unit coverage for diffing: fast/quality change detection, bounding boxes, SSIM clamping (`swift test --package-path Core/PeekabooCore --filter WatchCaptureSessionTests`).
- Future: add CLI automation tests for parsing defaults, heartbeat, contact sheet generation, hysteresis (enter/exit thresholds), frame-cap / size-cap early stop, window-closed warning, display-change warning, and metadata contents.
- Integration: run `peekaboo watch --mode screen --duration 5 --active-fps 8 --threshold 0` and assert ≥N frames, contact sheet exists.
- Regression: ensure `image`/`see` unaffected (shared screen recording guard remains). Add concurrency lint checks per repo norms.

## Rollout Steps
1. Implement `WatchCaptureOptions/Result` in `PeekabooCore`.
2. Build `SmartCaptureSession` with idle/active switch, SSIM diff, frame writing, contact sheet.
3. Add CLI command + Commander metadata, plumbing options and JSON output mirror of `ImageCommand`.
4. Add MCP tool exposure.
5. Update docs: new `docs/commands/watch.md` entry (parallel to `image.md`) and link from `docs/cli-command-reference.md`.
6. Run `pnpm run check` (or repo green gate) after adding tests.

## Open Decisions (confirm with stakeholders before coding)
- Final defaults: `duration=60s`, `idle-fps=2`, `active-fps=8`, `threshold=2.5%`, `heartbeat=5s`, `quiet-ms=1000`, `max-frames=800`, `max-mb` unset by default.
- Resolution cap: keep 1440p default or allow full native; current plan uses 1440p cap to balance I/O.
- Motion box overlays: remain opt-in or on by default? Plan assumes opt-in to keep images clean.
- Contact sheet sampling: include all frames when ≤ (cols*rows), else uniform sampling—confirm max grid size (default 6 cols, auto rows).
