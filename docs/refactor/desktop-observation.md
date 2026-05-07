---
summary: 'Grand refactor plan for unifying Peekaboo screenshot, AX detection, OCR, annotations, and desktop observation architecture.'
read_when:
  - 'planning major refactors to see, image, capture, or element detection'
  - 'changing screenshot performance, AX traversal, or capture target selection'
  - 'splitting ScreenCaptureService or ElementDetectionService'
  - 'moving CLI capture behavior into AutomationKit'
  - 'debugging app-window selection, Retina scale, or annotation output'
---

# Desktop Observation Refactor

## Thesis

Peekaboo should have one product-level answer to this question:

> What is visible on the desktop, where did it come from, what pixels represent it, and what can I do with it?

Today that answer is still spread across command code, MCP tools, capture services, element detection, menu-bar helpers, annotation renderers, and snapshot writers. The grand refactor is to make `DesktopObservationService.observe(_:)` the single behavioral pipeline for desktop inspection, then make CLI/MCP/agent tools thin adapters.

The desired shape is:

```text
CLI / MCP / agent request
  -> DesktopObservationRequest
  -> request-scoped DesktopStateSnapshot
  -> ObservationTargetResolver
  -> CapturePlan
  -> CaptureExecutor
  -> ElementObservationService
  -> ObservationOutputWriter
  -> DesktopObservationResult
  -> CLI / MCP / agent renderer
```

Command files should parse flags and render typed results. They should not rank windows, infer Retina scale, traverse AX, choose focus fallback behavior, build screenshot companion paths, or decide where snapshots live.

## Status: May 7, 2026

This plan is active and partially landed.

Landed:

- `DesktopObservationRequest`, target, capture, detection, output, timeout, timing, diagnostic, and result models.
- `DesktopObservationService` facade in `PeekabooAutomationKit`.
- `ObservationTargetResolver` for core targets.
- Request-scoped `DesktopStateSnapshot` for target resolution and diagnostics.
- `ObservationOutputWriter` for raw screenshot persistence, annotated companion-path planning, basic annotation rendering, and snapshot registration.
- Observation-backed paths for CLI `see`, CLI `image`, MCP `see`, and MCP `image`.
- Request-scoped capture engine preference through observation.
- Observation detection timeout enforcement.
- Central screen capture scale planning for logical 1x versus native Retina output.
- Direct `ElementDetectionService` timeout racing through `ElementDetectionTimeoutRunner`.
- AX traversal policy extraction into `AXTraversalPolicy`.
- AX tree cache state extraction into `ElementDetectionCache`.
- AX role/actionability/shortcut/attribute policy extraction into `ElementClassifier`.
- Batched AX descriptor reads and AX value coercion through `AXDescriptorReader`.
- Element grouping and metadata assembly through `ElementDetectionResultBuilder`.
- Sparse Chromium/Tauri web focus recovery through `WebFocusFallback`.
- Generic-group text-field recovery through `ElementTypeAdjuster`.
- Application menu-bar element collection through `MenuBarElementCollector`.
- Accessibility tree traversal through `AXTreeCollector`.
- Detection app/window fallback selection through `ElementDetectionWindowResolver`.
- Capture frame-source policy and display-local source-rectangle planning through `ScreenCapturePlanner`.
- Screen Recording enforcement through `ScreenCapturePermissionGate`.
- Logical 1x capture downscaling through `ScreenCaptureImageScaler`.
- Legacy area capture through the legacy capture operator.
- Dedicated ScreenCaptureKit and legacy capture operator files.
- Observation-backed CLI/MCP structured timings and diagnostics.
- Observation target selection for remaining CLI app-window filtering in `image`, live `capture`, and `window list`.
- Observation-backed menu-bar strip capture for CLI `image --app menubar` and MCP `image`.
- Observation-backed menu-bar popover window-list resolution and capture.
- MCP `see` uses observation-produced annotated screenshots before falling back to its local renderer.
- Observation-backed CLI `see` registers raw screenshots and detection results through observation output.
- CLI `see --annotate` uses observation output and the shared observation annotation renderer for observation-backed captures.
- Observation output reports artifact subspans for raw screenshot writes, annotation rendering, and snapshot registration.
- Desktop observation now has first-class OCR results, a `detection.ocr` timing span, OCR-only detection for `preferOCR`, and shared OCR-to-element mapping used by menu-bar helpers.
- CLI `see --menubar` now tries observation-backed already-open popover capture and OCR before falling back to the legacy click-to-open flow.
- Popover-specific OCR selection now lives in observation via shared candidate-window, preferred-area, and AX-menu-frame matching helpers.
- Menu-bar popover click-to-open capture now lives behind the typed observation target option `openIfNeeded`.
- Menu-bar strip and popover observation diagnostics now share typed target-resolution metadata for source, bounds, hints, window IDs, and click-open fallbacks.
- `peekaboo menubar list` and `peekaboo list menubar` now share the same JSON payload and text list formatting.
- CLI `see` all-screens capture now uses the shared screen inventory instead of command-local ScreenCaptureKit display enumeration.

Still incomplete:

- Further capture-service file splitting and cleanup after command bridges disappear.
- Further element-detection cleanup after extracted collaborators fully own policy.
- Interaction commands reusing observation state instead of repeating lookup work.
- Optional module extraction after boundaries are stable.

## Non-Negotiable Invariants

- Equivalent targets resolve the same way in CLI and MCP.
- `image --app X` and `see --app X` choose the same app window.
- `image --window-id N` and `see --window-id N` report the same window identity.
- `--window-id` beats title, title beats index, index beats automatic selection.
- Automatic app-window selection skips helper/offscreen/minimized windows when a renderable alternative exists.
- Automatic app-window selection prefers visible titled windows, then larger renderable area, then stable CoreGraphics ordering.
- `--retina` means native display scale; non-retina capture means logical 1x only where explicitly requested.
- Capture engine forcing never silently falls back to another engine.
- Screen Recording permission is checked once per capture operation.
- `image` never instantiates or runs element detection.
- A window-targeted `see` never traverses all app windows when a direct window context is available.
- Rich native AX trees skip Chromium/Tauri web focus fallback.
- Sparse Chromium/Tauri AX trees can still trigger web focus fallback.
- Request caches may reuse expensive enumeration inside one observation call; persistent caches must not hold live windows/elements.
- Output writing can create files and snapshots, but output formatting stays in CLI/MCP layers.
- Timings are structured spans, not prose logs that tests or benchmarks scrape.

## Target Architecture

### Public Facade

```swift
@MainActor
public protocol DesktopObservationServiceProtocol {
    func observe(_ request: DesktopObservationRequest) async throws -> DesktopObservationResult
}

@MainActor
public final class DesktopObservationService: DesktopObservationServiceProtocol {
    public func observe(_ request: DesktopObservationRequest) async throws -> DesktopObservationResult
}
```

`DesktopObservationService` owns:

- request-scoped desktop inventory;
- target resolution;
- capture planning;
- capture execution;
- optional element detection;
- optional OCR;
- optional annotation rendering;
- optional snapshot registration;
- structured timings;
- typed diagnostics;
- capture/detection timeout policy.

It does not own:

- Commander option declarations;
- MCP wire wording;
- CLI text or JSON rendering;
- AI provider calls that depend on Tachikoma;
- long-lived automation action orchestration.

### Request Model

```swift
public struct DesktopObservationRequest: Sendable, Equatable {
    public var target: DesktopObservationTargetRequest
    public var capture: DesktopCaptureOptions
    public var detection: DesktopDetectionOptions
    public var output: DesktopObservationOutputOptions
    public var timeout: DesktopObservationTimeouts
}
```

Target requests:

```swift
public enum DesktopObservationTargetRequest: Sendable, Equatable {
    case screen(index: Int?)
    case allScreens
    case frontmost
    case app(identifier: String, window: WindowSelection?)
    case pid(Int32, window: WindowSelection?)
    case windowID(CGWindowID)
    case area(CGRect)
    case menubar
    case menubarPopover(hints: [String])
}

public enum WindowSelection: Sendable, Equatable {
    case automatic
    case index(Int)
    case title(String)
    case id(CGWindowID)
}
```

Capture options:

```swift
public struct DesktopCaptureOptions: Sendable, Equatable {
    public var engine: CaptureEnginePreference
    public var scale: CaptureScalePreference
    public var focus: CaptureFocus
    public var visualizerMode: CaptureVisualizerMode
    public var includeMenuBar: Bool
}
```

Detection options:

```swift
public struct DesktopDetectionOptions: Sendable, Equatable {
    public var mode: DetectionMode
    public var allowWebFocusFallback: Bool
    public var includeMenuBarElements: Bool
    public var preferOCR: Bool
    public var traversalBudget: AXTraversalBudget
}

public enum DetectionMode: Sendable, Equatable {
    case none
    case accessibility
    case accessibilityAndOCR
}
```

Output options:

```swift
public struct DesktopObservationOutputOptions: Sendable, Equatable {
    public var path: String?
    public var format: ImageFormat
    public var saveRawScreenshot: Bool
    public var saveAnnotatedScreenshot: Bool
    public var saveSnapshot: Bool
    public var snapshotID: String?
}
```

Result:

```swift
public struct DesktopObservationResult: Sendable {
    public var target: ResolvedObservationTarget
    public var capture: CaptureResult
    public var elements: ElementDetectionResult?
    public var ocr: OCRResult?
    public var files: DesktopObservationFiles
    public var timings: ObservationTimings
    public var diagnostics: DesktopObservationDiagnostics
}
```

### Identity Model

Every frontend should use the same identity vocabulary.

```swift
public struct ApplicationIdentity: Sendable, Codable, Equatable, Hashable {
    public var processID: pid_t
    public var bundleIdentifier: String?
    public var name: String
    public var path: String?
}

public struct WindowIdentity: Sendable, Codable, Equatable, Hashable {
    public var windowID: CGWindowID?
    public var index: Int?
    public var ownerPID: pid_t?
    public var ownerName: String?
    public var title: String
    public var bounds: CGRect
    public var layer: Int
    public var alpha: Double
    public var isOnScreen: Bool
}
```

These identities must flow through:

- `list windows`;
- `image --app`;
- `image --window-id`;
- `see --app`;
- `see --window-id`;
- MCP `image`;
- MCP `see`;
- snapshot metadata;
- annotation metadata;
- interaction diagnostics.

### Request-Scoped Desktop State

Observation should build one request-scoped desktop inventory and pass it through the pipeline.

```swift
public struct DesktopStateSnapshot: Sendable {
    public var capturedAt: Date
    public var displays: [DisplayIdentity]
    public var runningApplications: [ApplicationIdentity]
    public var windows: [WindowIdentity]
    public var frontmostApplication: ApplicationIdentity?
    public var frontmostWindow: WindowIdentity?
}
```

Cache tiers:

```text
request cache: always allowed, discarded after one observation
short TTL cache: allowed after benchmarks prove it helps
persistent cache: static metadata only, never live windows/elements/pixels
```

Initial TTL guidance:

```text
window inventory: 150-300 ms
frontmost app/window: no TTL unless measured safe
AX element tree: 250-500 ms, keyed by pid + windowID + focus epoch
OCR output: no cache initially
screenshot pixels: no cache
```

AX cache invalidation triggers:

- target PID or window ID changed;
- window bounds changed;
- frontmost app changed;
- click/type/scroll/drag/hotkey/focus executed;
- focus fallback executed;
- detection options changed;
- timeout/cancellation occurred before traversal completed.

The cache stores immutable detection outputs, not live `AXUIElement` handles.

## Internal Collaborators

### `ObservationTargetResolver`

Owns:

- app name, bundle ID, and PID lookup;
- `frontmost`;
- `windowID`;
- window title/index selection;
- largest visible fallback;
- menubar strip;
- menubar popover windows;
- offscreen/minimized/helper filtering;
- diagnostics for skipped candidates.

Migrates behavior out of:

- `ImageCommand`;
- `SeeCommand`;
- MCP `SeeTool` and `ImageTool`;
- `WindowFilterHelper`;
- command-level CoreGraphics helpers.

### `ScreenCapturePlanner`

Owns pure capture policy:

- engine choice;
- forced-engine behavior;
- fallback eligibility;
- focus policy;
- display-local source rectangle planning;
- scale source and output scale;
- expected pixel dimensions when knowable.

Planner tests must not need Screen Recording permission.

### Capture Operators

Execution types own platform calls only:

- `ScreenCaptureKitOperator`;
- `LegacyScreenCaptureOperator`;
- `ScreenCaptureFallbackRunner`;
- `ScreenCapturePermissionGate`;
- `ScreenCaptureImageScaler`;
- `CaptureImageWriter`.

Hard rule: `ScreenCaptureService` remains the public facade, but should become mostly orchestration.

### `ElementObservationService`

Thin observation adapter over detection.

Owns:

- whether detection runs;
- `WindowContext` handoff;
- detection timeout budget;
- `allowWebFocusFallback`;
- menu-bar element inclusion;
- OCR preference handoff.

It should not re-resolve app/window target identity from scratch.

### Element Detection Internals

`ElementDetectionService` remains the facade, backed by:

- `AXTreeCollector`: traversal only;
- `AXTraversalPolicy`: depth, child count, skip rules, sparse-tree thresholds;
- `AXDescriptorReader`: batched attributes and actions;
- `ElementClassifier`: role, label, type, enabled, actionable, shortcut policy;
- `WebFocusFallback`: Chromium/Tauri sparse-tree focus recovery;
- `ElementTypeAdjuster`: post-classification corrections;
- `MenuBarElementCollector`: app menu-bar elements;
- `ElementDetectionWindowResolver`: fallback AX root/window selection;
- `ElementDetectionCache`: immutable detection caches and invalidation;
- `ElementDetectionResultBuilder`: grouping, metadata, warnings, snapshot result assembly.

### `ObservationOutputWriter`

Owns file and artifact side effects:

- raw screenshot path selection;
- format conversion;
- annotated screenshot path selection;
- annotated screenshot rendering;
- OCR artifact path selection;
- snapshot ID/path registration;
- output write warnings.

It does not print.

Required span names:

```text
target.resolve
desktop.snapshot
permission.screen-recording
focus.window
capture.plan
capture.window
capture.screen
capture.area
capture.write-file
detection.ax
detection.ocr
snapshot.write
annotation.render
desktop.observe
```

## Refactor Tracks

### Track A: Observation Is The Product Surface

Goal: every desktop inspection frontend constructs `DesktopObservationRequest` and receives `DesktopObservationResult`.

Remaining work:

- move menu-bar popover OCR under observation;
- move menu-bar click-to-open into either observation preflight or the future interaction pipeline;
- delete command-level capture/detection bridge code once all supported targets are observation-backed.

Done when:

- `see`, `image`, MCP `see`, and MCP `image` have no independent target-resolution behavior;
- command code only maps flags and renders output;
- unsupported targets fail explicitly instead of silently taking legacy paths.

### Track B: Capture Is Plan Plus Operators

Goal: `ScreenCaptureService` is a facade over pure planning plus small execution operators.

Remaining work:

- audit `ScreenCaptureService.swift` for residual policy;
- extract any remaining output-writing or target-selection policy;
- make native/logical scale decisions fully reportable in JSON diagnostics;
- keep `screencapture -l <windowID>` as the behavioral reference for native window capture where macOS permits it;
- remove direct command imports of ScreenCaptureKit/AppKit capture details.

Done when:

- scale, engine, fallback, and permission behavior have pure tests;
- `ScreenCaptureService.swift` is under about 500 lines;
- no command imports `ScreenCaptureKit`;
- `image --retina` and non-retina output can be reasoned about without live display capture.

### Track C: Element Detection Is Policy Plus Readers

Goal: `ElementDetectionService` facade contains orchestration, not a hidden mega-algorithm.

Remaining work:

- finish moving fallback thresholds into `AXTraversalPolicy`;
- audit direct detection callers for real timeout/cancellation;
- ensure rich native trees skip web focus fallback;
- ensure sparse Chromium/Tauri trees can still trigger fallback;
- isolate any remaining snapshot write behavior from detection;
- reduce service file size and tighten collaborator tests.

Done when:

- `ElementDetectionService.swift` is under about 500 lines;
- traversal policy has pure unit coverage;
- descriptor reader/classifier/result builder are independently testable;
- direct detection callers cannot hang forever.

### Track D: Interactions Reuse Observation

Goal: click/type/scroll/drag/hotkey reuse observation state when available and invalidate it when they mutate UI.

Future work:

- create an `ObservationSnapshotStore` facade over current snapshot manager behavior;
- make action commands accept a fresh observation result or snapshot ID;
- add observe-if-needed behavior for stale or missing element IDs;
- add target-point diagnostics for click/move without a full desktop scan;
- add explicit cache invalidation after click/type/scroll/drag/hotkey/focus.

Done when:

- `see -> click -> type` avoids avoidable full AX traversals;
- stale element failures explain stale snapshot/window identity;
- action commands invalidate only affected observation cache entries.

### Track E: Module Extraction Last

Goal: split packages only after behavior boundaries are boring.

Order:

1. `PeekabooObservation`
2. `PeekabooCapture`
3. `PeekabooElementDetection`
4. optional CLI command-support package

Do not extract modules while command, capture, and detection code still disagree about target semantics.

## Ship Groups

Each group should be shippable. Update this section after each commit lands.

### Group 1: Finish Observation Artifacts

Purpose: make observation own screenshot-derived artifacts.

Work:

- done: render annotated screenshots in `ObservationOutputWriter`;
- done: route MCP annotated screenshots through observation first;
- done: move CLI rich annotation placement into AutomationKit through `ObservationAnnotationRenderer`;
- done: add output spans for `output.raw.write`, `annotation.render`, and `snapshot.write`;
- done: add tests for raw+annotated output files and snapshot registration.

Gate:

```bash
swift test --package-path Core/PeekabooAutomationKit --filter DesktopObservationServiceTests
swift test --package-path Core/PeekabooCore --filter MCPToolExecutionTests
swift test --package-path Apps/CLI -Xswiftc -DPEEKABOO_SKIP_AUTOMATION --filter SeeCommandAnnotationTests
pnpm run test:safe
```

Manual checks:

```bash
peekaboo see --window-id <id> --annotate --path /tmp/see.png --json-output
sips -g pixelWidth -g pixelHeight /tmp/see.png /tmp/see_annotated.png
```

### Group 2: Menubar Observation Closure

Purpose: make menubar capture/OCR/click-open behavior one observation sub-pipeline.

Work:

- done: move generic OCR timing/output and OCR-to-element conversion into observation;
- done: route already-open `see --menubar` popovers through observation OCR before legacy fallback;
- done: move popover-specific OCR selection into observation;
- done: move popover click-to-open preflight behind a typed option;
- done: ensure `.menubar` and `.menubarPopover(hints:)` share diagnostics;
- done: keep menu-extra listing behavior consistent with `list menubar`.

Gate:

```bash
swift test --package-path Core/PeekabooAutomationKit --filter DesktopObservationServiceTests
pnpm run test:safe
```

Manual checks:

```bash
peekaboo see --menubar --json-output --verbose
peekaboo image --app menubar --path /tmp/menubar.png --json-output
```

### Group 3: Capture Service Cleanup

Purpose: finish the plan/operator split and remove residual command capture policy.

Work:

- in progress: audit all command imports for `ScreenCaptureKit`, capture-only `AppKit`, and direct CoreGraphics window work;
- finish splitting capture output helpers;
- ensure forced engine and fallback behavior is covered;
- add diagnostics for output scale, native scale, final pixel size, engine, and fallback reason;
- keep `ScreenCaptureService` under target size.

Gate:

```bash
swift test --package-path Core/PeekabooCore --filter ScreenCaptureService
swift test --package-path Core/PeekabooCore --filter CaptureEngineResolverTests
pnpm run test:safe
```

Manual Retina check:

```bash
peekaboo image --window-id <id> --path /tmp/no-retina.png --json-output
peekaboo image --window-id <id> --retina --path /tmp/retina.png --json-output
sips -g pixelWidth -g pixelHeight /tmp/no-retina.png /tmp/retina.png
```

### Group 4: Detection Service Cleanup

Purpose: finish isolating AX traversal, fallback, and result policy.

Work:

- move any remaining sparse-tree thresholds into `AXTraversalPolicy`;
- remove snapshot/file-writing behavior from detection internals;
- add cancellation tests for direct detection calls;
- add unit tests for rich-tree versus sparse-web fallback;
- keep `ElementDetectionService` under target size.

Gate:

```bash
swift test --package-path Core/PeekabooAutomationKit --filter ElementDetectionServiceTests
swift test --package-path Core/PeekabooAutomationKit --filter ElementDetectionTraversalPolicyTests
pnpm run test:safe
```

### Group 5: Interaction Integration

Purpose: make action commands consume observation state and invalidate caches.

Work:

- define snapshot freshness and stale-window diagnostics;
- teach click/type/scroll/drag to accept fresh observation context where available;
- add observe-if-needed for missing/stale element IDs;
- centralize post-action invalidation;
- add target-point diagnostics.

Gate:

```bash
swift test --package-path Apps/CLI -Xswiftc -DPEEKABOO_SKIP_AUTOMATION --filter ClickCommandTests
swift test --package-path Apps/CLI -Xswiftc -DPEEKABOO_SKIP_AUTOMATION --filter TypeCommandTests
pnpm run test:safe
```

Manual checks:

```bash
peekaboo see --app TextEdit --json-output --path /tmp/textedit.png
peekaboo click --snapshot <snapshot-id> --on <element-id> --json-output
peekaboo type "observation smoke test" --snapshot <snapshot-id> --json-output
```

### Group 6: Command and Module Cleanup

Purpose: make CLI/MCP boring and prepare package extraction.

Work:

- delete obsolete bridge helpers;
- move request mapping into small command-support adapters;
- archive stale refactor notes;
- update command docs for changed diagnostics/timings;
- only then consider module extraction.

Gate:

```bash
pnpm run format
pnpm run lint
pnpm run test:safe
```

Acceptance:

- `SeeCommand.swift` under about 400 lines;
- `ImageCommand.swift` under about 400 lines;
- command files do not import `AXorcist` or `ScreenCaptureKit`;
- CLI and MCP share observation request mapping.

## Testing Strategy

### Pure Tests

Add or keep tests for:

- target resolver ranking;
- offscreen/minimized/helper filtering;
- largest visible window fallback;
- `windowID` precedence;
- `--retina` to native scale mapping;
- logical 1x scale planning;
- forced engine behavior;
- no fallback when engine is forced;
- detection mode selection;
- web focus fallback policy;
- output path planning;
- annotation rendering path;
- structured span emission.

### Stubbed Integration Tests

Use fake services for:

- app/window inventory;
- capture output;
- element detection;
- OCR;
- output writing.

Verify:

- `see` requests detection;
- `image` does not request detection;
- MCP `see` and CLI `see` map equivalent targets;
- MCP `image` and CLI `image` map equivalent targets;
- menubar capture sets OCR preference;
- annotation requests create annotation output;
- timeout settings flow to capture/detection.

### Live E2E

Run only when Screen Recording and Accessibility are granted.

```bash
peekaboo permissions status --json-output
peekaboo list windows --app TextEdit --json-output
peekaboo image --window-id <id> --path /tmp/textedit.png --json-output
peekaboo image --window-id <id> --retina --path /tmp/textedit-retina.png --json-output
peekaboo see --window-id <id> --annotate --path /tmp/textedit-see.png --json-output --verbose
peekaboo see --app "Google Chrome" --json-output --verbose
peekaboo see --app "Peekaboo Inspector" --json-output --verbose
```

Record:

- wall time;
- `desktop.observe`;
- `target.resolve`;
- capture span;
- detection span;
- OCR/annotation spans if used;
- element count;
- interactable count;
- target window ID/title;
- screenshot dimensions.

### Performance Budgets

Budgets are manual benchmark targets, not flaky unit-test thresholds.

Warm local desktop targets:

```text
permissions status: <100 ms
list windows --app: <250 ms
image --window-id: <500 ms
image --app: <700 ms
see --window-id, native AX tree: <1500 ms
see --app, native AX tree: <1800 ms
see sparse Chromium/Tauri with focus fallback: <2500 ms
```

Treat these as bugs:

- `image` runs element detection;
- local commands probe bridge or remote endpoints by default;
- permission checks happen twice;
- fallback focus runs after a rich native tree;
- command runtime spends meaningful time formatting JSON compared with capture/detection;
- window-targeted detection traverses the entire app when a window context exists.

## Risk Areas

### Retina Scale

`image --retina` must produce native pixels on Retina displays. Keep pure planner tests and live `sips` checks. Do not infer Retina behavior from output-path code.

### Tauri/Electron/Chromium

These apps often expose many helper windows and sometimes sparse AX trees. Automatic target selection should choose the main visible window; sparse-tree fallback should run only when the native tree is actually sparse.

### Menubar Popovers

Menubar popovers mix click-to-open behavior, window-list capture, AX, OCR, and area fallback. Keep it as a typed observation sub-pipeline with explicit diagnostics.

### Bridge/Remote

Do not force bridge APIs to accept the full observation request until local behavior is stable. Keep request mapping parity tests so remote observation can be added later without drift.

### Snapshot Compatibility

Preserve snapshot behavior unless deliberately migrated:

- same snapshot JSON shape where possible;
- stable element IDs for equivalent captures where possible;
- annotated screenshot paths stored consistently;
- stale snapshot failures explain target/window identity.

## Whole-Refactor Acceptance

- `DesktopObservationService.observe(_:)` is the only behavioral path for `see`, `image`, MCP `see`, and MCP `image`.
- `SeeCommand.swift` is under about 400 lines.
- `ImageCommand.swift` is under about 400 lines.
- `ScreenCaptureService.swift` is under about 500 lines.
- `ElementDetectionService.swift` is under about 500 lines.
- CLI command files no longer import `AXorcist` or `ScreenCaptureKit`.
- `image --app X` and `see --app X` choose the same app window.
- `image --window-id N` and `see --window-id N` report the same window identity.
- `--retina` produces native display scale where macOS allows it.
- Structured timings are available in CLI JSON and MCP metadata.
- No duplicated Screen Recording preflight.
- No default bridge probe for local read-only commands.
- No app-root AX traversal for a window capture.
- Rich native AX trees skip web focus fallback.
- Sparse web AX trees can still use web focus fallback.
- Observation output owns raw screenshot, annotation, OCR artifact, and snapshot side effects.
- Interaction commands can reuse observation state or explain why they cannot.
- `pnpm run format`, `pnpm run lint`, and `pnpm run test:safe` pass.
- Targeted Core observation, capture, and element detection tests pass.
- Live TextEdit, Chrome, and Peekaboo Inspector E2E runs are recorded with screenshots and timings.

## Changelog Discipline

For each shipped group:

- add a concise `CHANGELOG.md` entry;
- mention user-visible behavior changes such as target selection, Retina scale, diagnostics, or timings;
- mention contributor fixes when the group closes a GitHub issue or PR thread;
- keep internal-only extraction notes short unless they change performance or behavior.

## Open Questions

- Should observation become a bridge endpoint after local CLI/MCP behavior is stable?
- Should AI image analysis become an observation enhancement, or stay above AutomationKit because it depends on Tachikoma?
- Should `CaptureTarget` be fully replaced by `DesktopObservationTargetRequest`, or wrapped during module extraction?
- Should OCR move into AutomationKit now, or wait until annotation and snapshot output are fully centralized?
- Should annotation use one rich renderer everywhere, or keep a simple Core renderer in AutomationKit plus a richer CLI renderer until dependencies are untangled?
