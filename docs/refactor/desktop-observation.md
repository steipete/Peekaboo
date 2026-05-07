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
- `peekaboo image --json` includes per-file observation diagnostics with timing spans, state snapshot summaries, warnings, and resolved target metadata.
- Observation target selection for remaining CLI app-window filtering in `image`, live `capture`, and `window list`.
- Observation-backed menu-bar strip capture for CLI `image --app menubar` and MCP `image`.
- Observation-backed menu-bar popover window-list resolution and capture.
- MCP `see` uses observation-produced annotated screenshots and no longer carries its own annotation renderer.
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
- `peekaboo image` builds desktop observation requests through a dedicated command-support adapter.
- `peekaboo see` builds desktop observation requests through a dedicated command-support adapter.
- `peekaboo see --mode screen --screen-index <n>` and screen analysis captures now route through desktop observation; all-screen capture remains on the legacy multi-file path until observation grows multi-artifact output.
- `peekaboo see --json` now reports an annotated screenshot path only when an annotated file actually exists.
- `peekaboo see` support types, output rendering, and screen helpers are split out of the primary command file.
- `peekaboo see` legacy capture/detection fallback now lives in a dedicated detection-pipeline adapter, putting the main command shell under the target size.
- `peekaboo image` capture orchestration, output models, analysis rendering, filename planning, and focus helpers are split out of the primary command file.
- `peekaboo app` launch, quit, and relaunch implementations now live in focused support files, leaving `AppCommand.swift` under the target size.
- `peekaboo menu` list output filtering, typed JSON conversion, and text rendering now share one command-support helper.
- `peekaboo click`, `type`, `move`, `scroll`, `drag`, `swipe`, `hotkey`, and `press` now use a shared interaction observation context for explicit/latest snapshot selection and focus snapshot policy.
- Element-targeted interaction commands now share one stale-snapshot refresh helper instead of maintaining command-local refresh loops.
- `peekaboo click`, `type`, `scroll`, `drag`, and `swipe` now centrally invalidate implicitly reused latest snapshots after successful UI mutations.
- Element-targeted actions now receive stale-window diagnostics when a snapshot window disappears or changes size.
- Element-targeted move, drag, swipe, click output, and scroll targeting now share the core moved-window point adjustment.
- Disk and in-memory snapshot stores now preserve typed detection window context so observation-backed snapshots keep bundle ID, PID, window ID, and bounds.
- App launch/switch, window mutation, hotkey, press, and paste commands now invalidate the implicit latest snapshot after UI changes.
- `peekaboo click --on/--id`, `click <query>`, `move --on/--id`, `move --to <query>`, `scroll --on`, `drag --from/--to`, and `swipe --from/--to` now refresh the implicit observation snapshot once when cached element targets are missing.
- `peekaboo scroll --smooth --json` now reports the actual smooth scroll tick count used by the automation service.
- `peekaboo scroll --on --json` now reports the same moved-window-adjusted target point used by the automation service.
- `peekaboo window focus --snapshot` now focuses the captured window context while preserving explicit snapshots during focus-cache invalidation.
- Element-targeted `click`, `move`, `scroll`, `drag`, and `swipe` JSON results now report target-point diagnostics with original snapshot point, resolved point, snapshot ID, and moved-window adjustment.
- `ElementDetectionService` now owns only detection/result building; snapshot persistence moved up to orchestration.
- Exact CoreGraphics window-ID metadata lookup now lives in `WindowCGInfoLookup`, keeping `WindowManagementService` focused on window operations and fallback orchestration.
- Shared `peekaboo window` target, display-name, action-result, and snapshot-invalidation helpers now live in `WindowCommand+Support`, leaving the primary command file focused on subcommand wiring.
- Watch capture frame diffing now lives in `WatchFrameDiffer`, keeping luma scaling, bounding-box extraction, and SSIM away from session orchestration.
- Watch capture artifact writing now lives in `WatchCaptureArtifactWriter`, keeping PNG encoding, contact sheets, resizing, and change highlighting away from session orchestration.
- Watch capture session filesystem duties now live in `WatchCaptureSessionStore`, keeping output directory setup, managed autoclean, and metadata JSON writing out of session orchestration.
- Watch capture region validation now lives in `WatchCaptureRegionValidator`, keeping visible-screen clamping and region warnings out of session orchestration.
- Watch capture result assembly now lives in `WatchCaptureResultBuilder`, keeping stats, options snapshots, no-motion warnings, and result metadata out of session orchestration.
- Watch capture frame acquisition now lives in `WatchCaptureFrameProvider`, keeping live/video source selection, region-target capture, and resolution capping out of session orchestration.
- Watch capture active/idle hysteresis now lives in `WatchCaptureActivityPolicy`; the unused private motion-interval accumulator was removed from session state.
- Window operation orchestration now stays in `WindowManagementService`; target resolution, title search, and close-presence polling moved into dedicated service extension files.
- `peekaboo window` response models and Commander binding/conformance wiring now live in `WindowCommand+Bindings`, leaving the primary command file closer to behavior-only subcommands.
- `peekaboo window close`, `minimize`, and `maximize` implementations now live in `WindowCommand+State`.
- `peekaboo window move`, `resize`, and `set-bounds` implementations now live in `WindowCommand+Geometry`.
- `peekaboo window focus` and `list` implementations now live in `WindowCommand+Focus` and `WindowCommand+List`, leaving `WindowCommand.swift` as the command shell.
- Interaction snapshot invalidation now lives in `InteractionObservationInvalidator`, leaving `InteractionObservationContext` focused on snapshot selection and refresh.
- Observation label placement geometry and candidate generation now live in `ObservationLabelPlacementGeometry`, leaving `ObservationLabelPlacer` focused on scoring/orchestration.
- Desktop observation target diagnostics and trace timing now live in focused helpers, leaving `DesktopObservationService` focused on the observe pipeline.
- `peekaboo move` result and movement-resolution types now live in `MoveCommand+Types`.
- `peekaboo move` Commander wiring and cursor movement parameter policy now live in focused support files.
- Drag destination-app/Dock AX lookup now lives in a focused CLI helper, `swipe` no longer carries stale platform imports, and `move --center` uses the shared screen service instead of command-local AppKit.
- `image --app` auto focus now skips forced activation when a renderable target window already exists, fixing SwiftPM GUI captures that timed out while activation never completed.
- Observation app-target resolution now fails with a typed window-not-found error when known windows exist but none are renderable/shareable, instead of falling back to generic app capture.
- MCP `image` and `see` now share one observation target parser, including screen, frontmost, menubar, PID/window-index, app/window-index, and app/window-title targets; MCP `image` also maps `scale: native` and `retina: true` to native capture scale.
- `peekaboo type` text escape processing and result DTOs now live in focused support files.
- Drag/swipe element-or-coordinate point resolution now uses `InteractionTargetPointResolver.elementOrCoordinateResolution`, and gesture result DTOs live in focused type files.
- `peekaboo click` validation/helpers and Commander wiring now live in focused support files.
- `peekaboo click` coordinate focus verification now uses the application service boundary instead of command-local `NSWorkspace` frontmost-app reads.
- `peekaboo app switch --to` activation and `--cycle` input now use shared service boundaries instead of command-local `NSWorkspace`/`CGEvent` calls.
- `peekaboo menu click/list` frontmost-app fallback now uses the application service boundary instead of command-local `NSWorkspace` reads.
- Command utility, menubar, open, and space command files no longer carry stale `AppKit` imports when only Foundation/CoreGraphics APIs are used.
- The menu-bar popover detector helper no longer depends on `AppKit` for CoreGraphics-only window metadata filtering.
- Smart capture now receives frontmost-app and screen-bounds state through shared application and screen service boundaries instead of direct `AppKit` calls.
- Smart capture image decoding, thumbnail resizing, and perceptual hashing now live in a focused image processor helper.
- Smart capture region screenshots now clamp to the display containing the action target instead of always using the primary display.
- Observation target menu-bar resolution and window-selection scoring now live in focused resolver extension files.
- Desktop observation target, request, and result DTOs now live in focused model files.
- `DesktopObservationService` now keeps `observe` as orchestration, with capture, detection/OCR, and output-writing plumbing in focused extension files.
- MCP `see` request, output, and summary support now live in a companion file, leaving the primary tool under the size target.
- `DragDestinationResolver` now resolves app and Trash destinations through application, window, and Dock services instead of direct CLI AX/AppKit access.
- MCP `see` annotation output now depends on `ObservationOutputWriter` instead of a tool-local AppKit renderer.
- MCP `image` saved-file output now comes from `ObservationOutputWriter` instead of tool-local image encoding/writes.

Current status:

- Capture-service cleanup is mostly complete; `ScreenCaptureService.swift` is under the 500-line target and frontmost-app lookup is behind `ScreenCaptureApplicationResolver`.
- CLI sources no longer import `AXorcist` or `ScreenCaptureKit`; remaining AppKit use is app-management, visualizer demo state, screen inventory, or command helper behavior outside the capture pipeline.
- Observation resolver extensions no longer own broad CoreGraphics window-list scans. Menu-bar and exact-window metadata lookup now route through focused catalog helpers.
- Optional module extraction after boundaries are stable.

Current size pressure:

```text
ScreenCaptureService.swift: 491 lines
ScreenCaptureService+Support.swift: 19 lines
ScreenCaptureScaleResolver.swift: 115 lines
ScreenCaptureEngineSupport.swift: 207 lines
ScreenCaptureApplicationResolver.swift: 75 lines
ScreenCaptureKitCaptureGate.swift: 195 lines
WatchCaptureSession.swift: 486 lines
WatchCaptureArtifactWriter.swift: 150 lines
WatchFrameDiffer.swift: 250 lines
WatchCaptureSessionStore.swift: 49 lines
WatchCaptureRegionValidator.swift: 31 lines
WatchCaptureResultBuilder.swift: 96 lines
WatchCaptureFrameProvider.swift: 97 lines
WatchCaptureActivityPolicy.swift: 18 lines
WindowManagementService.swift: 406 lines
WindowManagementService+Resolution.swift: 197 lines
WindowManagementService+Search.swift: 158 lines
WindowManagementService+Presence.swift: 57 lines
WindowCGInfoLookup.swift: 91 lines
DesktopObservationService.swift: 97 lines
DesktopObservationService+Capture.swift: 142 lines
DesktopObservationService+Detection.swift: 176 lines
DesktopObservationService+Output.swift: 20 lines
DesktopObservationModels.swift: 15 lines
DesktopObservationTargetModels.swift: 191 lines
DesktopObservationRequestModels.swift: 120 lines
DesktopObservationResultModels.swift: 120 lines
DesktopObservationDiagnosticsBuilder.swift: 97 lines
DesktopObservationTraceRecorder.swift: 33 lines
ElementDetectionService.swift: 199 lines
ObservationTargetResolver.swift: 168 lines
ObservationTargetResolver+MenuBar.swift: 131 lines
ObservationTargetResolver+WindowSelection.swift: 119 lines
ObservationWindowMetadataCatalog.swift: 87 lines
ObservationLabelPlacer.swift: 425 lines
ObservationLabelPlacementGeometry.swift: 183 lines
WindowCommand.swift: 66 lines
WindowCommand+Bindings.swift: 187 lines
WindowCommand+Focus.swift: 253 lines
WindowCommand+Geometry.swift: 328 lines
WindowCommand+List.swift: 149 lines
WindowCommand+Support.swift: 189 lines
WindowCommand+State.swift: 250 lines
SeeCommand.swift: 308 lines
SeeCommand+CapturePipeline.swift: 221 lines
SeeCommand+DetectionPipeline.swift: 160 lines
SeeCommand+Output.swift: 204 lines
SeeCommand+Types.swift: 204 lines
SeeCommand+Screens.swift: 146 lines
SeeCommand+ObservationRequest.swift: 140 lines
ImageCommand.swift: 192 lines
ImageCommand+CapturePipeline.swift: 386 lines
ImageCommand+Output.swift: 102 lines
ImageCommand+ObservationRequest.swift: 56 lines
InteractionObservationContext.swift: 284 lines
InteractionObservationInvalidator.swift: 91 lines
InteractionTargetPointResolver.swift: 227 lines
ClickCommand.swift: 312 lines
ClickCommand+CommanderMetadata.swift: 92 lines
ClickCommand+Validation.swift: 79 lines
ClickCommand+FocusVerification.swift: 148 lines
ClickCommand+Output.swift: 30 lines
TypeCommand.swift: 337 lines
TypeCommand+TextProcessing.swift: 60 lines
TypeCommand+Types.swift: 11 lines
MoveCommand.swift: 322 lines
MoveCommand+CommanderMetadata.swift: 134 lines
MoveCommand+Movement.swift: 58 lines
MoveCommand+Types.swift: 59 lines
ScrollCommand.swift: 240 lines
DragCommand.swift: 295 lines
DragCommand+Types.swift: 15 lines
DragDestinationResolver.swift: 65 lines
SwipeCommand.swift: 295 lines
SwipeCommand+Types.swift: 15 lines
HotkeyCommand.swift: 272 lines
PressCommand.swift: 231 lines
```

Current command-boundary audit:

- CLI command sources no longer import `ScreenCaptureKit`.
- `see` all-screens capture no longer enumerates `SCShareableContent` directly.
- AI/Core capture command sources no longer import `AppKit`; `see`, `image`, `list`, and menu-bar geometry now use shared screen/application services for screen inventory and app identity checks.
- `SeeCommand+MenuBarCandidates.swift` uses the shared observation menu-bar window catalog instead of command-local `CGWindowListCopyWindowInfo`.
- Menu-bar click verification uses the shared observation window catalog instead of command-local `CGWindowListCopyWindowInfo`.

Near-term rule: command code may mention `CGWindowID` as a user-facing identifier, but must not enumerate windows, displays, or ScreenCaptureKit objects directly.

## Grand Execution Plan

This is the full refactor sequence. Keep every phase shippable: one coherent behavior boundary, one changelog entry, targeted tests, then the broad gate.

### Phase 1: Freeze Semantics

Purpose: prevent CLI, MCP, and agent tools from drifting while code moves.

Deliverables:

- one table of target precedence for `screen`, `frontmost`, `app`, `pid`, `window-title`, `window-index`, `window-id`, `area`, `menubar`, and `menubarPopover`;
- parity tests proving `image` and `see` construct equivalent observation targets for equivalent flags;
- parity tests proving CLI and MCP request mapping agree;
- diagnostics fixtures for skipped helper/offscreen/minimized windows;
- docs for native Retina versus logical 1x behavior.

Exit criteria:

- behavior changes require updating tests first;
- any legacy fallback path emits typed diagnostics explaining why observation did not handle it.

### Phase 2: Observation Owns Desktop State

Purpose: make one request-scoped inventory feed resolution, capture, detection, diagnostics, and interactions.

Deliverables:

- `DesktopStateSnapshot` is the only source for target resolution inside observation;
- `ObservationTargetResolver` owns all app/window ranking and menubar target resolution;
- window/application identity structs are used in observation results, snapshot metadata, CLI JSON, and MCP metadata;
- command-level window ranking, app matching, display enumeration, and menu-bar window polling are deleted;
- request-local cache invalidation rules are encoded near the snapshot builder.

Exit criteria:

- `image --app X` and `see --app X` choose the same window from the same ranked candidates;
- `image --window-id N` and `see --window-id N` report the same identity fields;
- commands cannot enumerate windows or displays directly.

### Phase 3: Capture Becomes Plan Plus Operators

Purpose: separate policy from macOS capture calls.

Deliverables:

- `ScreenCapturePlanner` is the only place deciding engine, scale, fallback eligibility, and source rectangles;
- `ScreenCaptureService` is a facade over permission gate, planner, operators, scaler, and metadata builder;
- operators contain platform calls only: ScreenCaptureKit, legacy CG capture, and future `screencapture` fallback if adopted;
- capture metadata always includes requested scale, native scale, output scale, final pixel size, engine, fallback reason, and permission timing;
- all pure capture decisions have tests without Screen Recording permission.

Exit criteria:

- `ScreenCaptureService.swift` stays under 500 lines;
- no command imports `ScreenCaptureKit`, `AppKit`, `NSScreen`, or `NSWorkspace` for capture behavior;
- live Retina checks are recorded against `screencapture -l <windowID> -o -x` on hardware that demonstrates native 2x output.

### Phase 4: Detection Becomes Policy Plus Readers

Purpose: make AX traversal fast, cancellable, and understandable.

Deliverables:

- `ElementDetectionService` orchestrates only;
- traversal, descriptor reads, classification, result assembly, window fallback, web focus fallback, menu-bar elements, and cache state remain in dedicated collaborators;
- direct detection callers use racing timeouts and cancellation;
- sparse web fallback is triggered by explicit policy, not by incidental missing labels;
- rich native windows never pay for web-content focus fallback.

Exit criteria:

- detection cannot hang indefinitely;
- window-targeted `see` does not traverse all app windows;
- `ElementDetectionService.swift` stays under 500 lines with policy tested outside the facade.

### Phase 5: Output And Snapshot Side Effects Are Central

Purpose: make all screenshot-derived artifacts predictable.

Deliverables:

- `ObservationOutputWriter` owns raw screenshot, annotated screenshot, OCR artifact, and snapshot registration side effects;
- CLI/MCP renderers only render existing typed result fields;
- output span names are stable and covered by tests;
- annotation rendering uses one shared coordinate model.

Exit criteria:

- `see --annotate` and MCP `see` produce the same companion path policy;
- snapshot metadata always references the resolved target identity and capture bounds;
- output writing never prints directly.

### Phase 6: Interactions Consume Observation

Purpose: make `see -> click/type/scroll` fast and explainable.

Deliverables:

- `ObservationSnapshotStore` facade over the current snapshot manager;
- action commands accept fresh observation context or snapshot ID;
- missing/stale element IDs can observe-if-needed or fail with target/window diagnostics;
- click/type/scroll/drag/swipe invalidate implicitly reused latest snapshots after mutations;
- hotkey/press/focus invalidation policy is explicit once they consume fresh observation context;
- stale snapshot failures identify the previous and current window identity;
- element target points share one snapshot-window movement adjustment path;
- action results include target-point and stale-snapshot diagnostics.

Exit criteria:

- repeated `see -> click -> type` avoids avoidable AX rescans;
- stale snapshot failures identify the previous and current window identity;
- action commands do not duplicate target resolution policy.

### Phase 7: Command Surface Cleanup

Purpose: make CLI/MCP files thin adapters.

Deliverables:

- `SeeCommand.swift` below 400 lines;
- `ImageCommand.swift` below 400 lines;
- command-support adapters for observation request mapping and result rendering;
- no CLI command imports `AXorcist` unless it directly implements an action that must touch AX handles;
- no CLI command imports platform capture frameworks;
- command docs updated for diagnostics and timings.

Exit criteria:

- command files parse flags, call services, render typed results, and little else;
- each helper file has one reason to change and stays under about 500 lines.

### Phase 8: Module Extraction

Purpose: split packages after boundaries are stable.

Order:

1. `PeekabooObservation`
2. `PeekabooCapture`
3. `PeekabooElementDetection`
4. optional CLI command-support package

Exit criteria:

- extraction is mostly moving files and access modifiers;
- package boundaries do not force semantic rewrites;
- broad gate and live E2E still pass after each extraction.

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
- click/type/scroll/drag/swipe/hotkey/press/focus executed;
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

- delete command-level capture/detection bridge code once all supported targets are observation-backed.
- move remaining legacy command helpers into observation or the future interaction pipeline.

Done when:

- `see`, `image`, MCP `see`, and MCP `image` have no independent target-resolution behavior;
- command code only maps flags and renders output;
- unsupported targets fail explicitly instead of silently taking legacy paths.

### Track B: Capture Is Plan Plus Operators

Goal: `ScreenCaptureService` is a facade over pure planning plus small execution operators.

Remaining work:

- audit `ScreenCaptureService.swift` for residual policy;
- extract any remaining output-writing or target-selection policy;
- keep `screencapture -l <windowID>` as the behavioral reference for native window capture where macOS permits it;
- keep native/logical scale decisions reportable through `CaptureMetadata.diagnostics`;
- keep command imports free of ScreenCaptureKit/AppKit capture details.

Done when:

- scale, engine, fallback, and permission behavior have pure tests;
- `ScreenCaptureService.swift` is under about 500 lines;
- `ScreenCaptureService+Support.swift` is split by responsibility and no single capture helper file exceeds about 500 lines;
- watch/session capture has a dedicated follow-up plan before `WatchCaptureSession.swift` is split, because it is long-lived streaming behavior rather than single-shot observation;
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

Goal: click/type/scroll/drag/swipe/hotkey/press reuse observation state when available and invalidate it when they mutate UI.

Future work:

- create an `ObservationSnapshotStore` facade over current snapshot manager behavior;
- extend the shared interaction observation context to focus commands and fresh observation results;
- add observe-if-needed behavior for stale or missing element IDs;
- add target-point diagnostics for click/move without a full desktop scan;
- add explicit cache invalidation after click/type/scroll/drag/swipe/hotkey/press/focus.

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

- done: remove command-local ScreenCaptureKit display enumeration from `see` all-screens capture;
- done: verify CLI sources no longer import `ScreenCaptureKit`;
- done: remove capture-facing command `AppKit`, `NSScreen`, `NSWorkspace`, and `NSRunningApplication` dependencies from AI/Core command sources;
- done: split `ScreenCaptureService+Support.swift` into focused scale, engine fallback, app resolving, and ScreenCaptureKit gate helpers;
- done: add `CaptureMetadata.diagnostics` for requested scale, native scale, output scale, final pixel size, engine, and fallback reason;
- done: cover forced engine resolution and fallback diagnostics in pure tests;
- done: migrate remaining `see` menu-bar candidate `CGWindowListCopyWindowInfo` work behind the shared observation window catalog;
- done: route menu-bar click verification window polling through the shared observation window catalog;
- done: move frontmost-application capture lookup behind the shared capture application resolver;
- done: remove stale `AXorcist` and `ScreenCaptureKit` imports from CLI command files;
- done: route menu-bar popover target resolution through the shared observation window catalog;
- done: route exact `--window-id` observation metadata through `ObservationWindowMetadataCatalog`;
- keep `ScreenCaptureService.swift` under target size and split support files that exceed it.

Recommended order:

1. Done: run live `sips` checks and compare against `screencapture -l <windowID> -o -x`.
2. Done: extract observation request mapping out of large `image` and `see` command files.

Live check, May 7, 2026:

```bash
./Apps/CLI/.build/debug/peekaboo list windows --app Ghostty --json-output
./Apps/CLI/.build/debug/peekaboo image --window-id 7565 --path /tmp/peekaboo-live-no-retina.png --json-output
./Apps/CLI/.build/debug/peekaboo image --window-id 7565 --retina --path /tmp/peekaboo-live-retina.png --json-output
screencapture -l 7565 -o -x /tmp/peekaboo-live-native.png
sips -g pixelWidth -g pixelHeight /tmp/peekaboo-live-no-retina.png /tmp/peekaboo-live-retina.png /tmp/peekaboo-live-native.png
```

Result on the current host: all three files were `802x1250`, so this machine/session does not reproduce a Retina 2x delta. `image --app Ghostty` selected the real `802x1250` titled window `Peekaboo` instead of the visible `3008x30` auxiliary strip windows, matching the intended #113 app-window behavior.

Gate:

```bash
swift test --package-path Core/PeekabooCore --filter ScreenCaptureService
swift test --package-path Core/PeekabooCore --filter CaptureEngineResolverTests
pnpm run test:safe
```
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

- done: move remaining sparse-tree thresholds into `AXTraversalPolicy`;
- done: remove snapshot/file-writing behavior from `ElementDetectionService`;
- done: add cancellation tests for direct detection timeout calls;
- done: add unit tests for rich-tree versus sparse-web fallback;
- done: keep `ElementDetectionService` under target size.

Gate:

```bash
swift test --package-path Core/PeekabooAutomationKit --filter ElementDetectionServiceTests
swift test --package-path Core/PeekabooAutomationKit --filter ElementDetectionTraversalPolicyTests
pnpm run test:safe
```

### Group 5: Interaction Integration

Purpose: make action commands consume observation state and invalidate caches.

Work:

- done: define shared explicit/latest snapshot selection and focus snapshot policy in `InteractionObservationContext`;
- done: teach click/type/move/scroll/drag/swipe/hotkey/press to resolve snapshot context through the shared helper;
- done: centralize stale-snapshot refresh loops for element-targeted interaction commands;
- done: centralize post-action invalidation for implicitly reused latest snapshots after click/type/scroll/drag/swipe;
- done: define stale-window diagnostics for disappeared or resized snapshot windows;
- done: centralize moved-window target-point adjustment for click/type/move/scroll/drag/swipe element paths;
- done: preserve typed detection window context in disk and in-memory snapshot stores;
- done: invalidate implicit latest snapshots after app launch/switch, window focus/geometry, hotkey, press, and paste changes;
- done: refresh implicit observation snapshot once for `click --on/--id`, `click <query>`, `move --on/--id`, `move --to <query>`, `scroll --on`, `drag --from/--to`, and `swipe --from/--to` when cached element targets are missing;
- done: broaden observe-if-needed from element IDs to implicit latest query targets while keeping no-snapshot query actions on their direct AX path;
- done: align smooth scroll result telemetry with the automation service tick configuration;
- done: share moved-window target-point resolution with scroll result rendering;
- done: teach `window focus` to accept explicit snapshot window context;
- done: preserve explicit snapshots while invalidating implicit latest state after focus commands;
- done: add target-point diagnostics.

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

- done: deleted obsolete bridge helper stubs and the command-local `ScreenCaptureBridge` shim;
- started: move request mapping into small command-support adapters (`ImageCommand+ObservationRequest.swift`, `SeeCommand+ObservationRequest.swift`);
- started: split large `see` support into focused files (`SeeCommand+Types.swift`, `SeeCommand+Output.swift`, `SeeCommand+Screens.swift`);
- done: move the remaining legacy capture/detection fallback body out of `SeeCommand.swift` into `SeeCommand+DetectionPipeline.swift`;
- done: split `ImageCommand.swift` request mapping, output rendering, analysis, and local fallback code until the command shell is under target size;
- done: split drag destination-app/Dock lookup out of `DragCommand.swift` and remove stale platform imports from `swipe`/`move`;
- done: route `DragDestinationResolver` through service boundaries and remove direct CLI AX/AppKit destination probing;
- done: archive stale refactor notes behind the current refactor index;
- done: update command docs for changed diagnostics/timings;
- done: split interaction target-point diagnostics out of `InteractionObservationContext.swift`;
- done: split `ClickCommand` focus verification and output models out of the command shell;
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
- CLI sources do not import `AXorcist` or `ScreenCaptureKit`;
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

Live verification, May 7, 2026:

```bash
./Apps/CLI/.build/debug/peekaboo permissions status --json --no-remote
./Apps/CLI/.build/debug/peekaboo list windows --app TextEdit --json --no-remote
./Apps/CLI/.build/debug/peekaboo list windows --app "Google Chrome" --json --no-remote
./Apps/CLI/.build/debug/peekaboo list windows --app PeekabooInspector --json --no-remote
./Apps/CLI/.build/debug/peekaboo image --window-id 13441 --path .artifacts/live-e2e/2026-05-07T1118Z/textedit-window.png --json --no-remote
./Apps/CLI/.build/debug/peekaboo image --app TextEdit --path .artifacts/live-e2e/2026-05-07T1118Z/textedit-app-fixed.png --json --no-remote
./Apps/CLI/.build/debug/peekaboo image --window-id 12438 --path .artifacts/live-e2e/2026-05-07T1118Z/chrome-window.png --json --no-remote
./Apps/CLI/.build/debug/peekaboo image --app "Google Chrome" --path .artifacts/live-e2e/2026-05-07T1118Z/chrome-app-fixed.png --json --no-remote
./Apps/CLI/.build/debug/peekaboo image --window-id 13665 --path .artifacts/live-e2e/2026-05-07T1118Z/inspector-window.png --json --no-remote
./Apps/CLI/.build/debug/peekaboo image --app PeekabooInspector --path .artifacts/live-e2e/2026-05-07T1118Z/inspector-app-fixed.png --json --no-remote
./Apps/CLI/.build/debug/peekaboo see --window-id 13441 --path .artifacts/live-e2e/2026-05-07T1118Z/textedit-see-window.png --json --no-remote
./Apps/CLI/.build/debug/peekaboo see --app TextEdit --path .artifacts/live-e2e/2026-05-07T1118Z/textedit-see-app.png --json --no-remote
./Apps/CLI/.build/debug/peekaboo see --window-id 12438 --path .artifacts/live-e2e/2026-05-07T1118Z/chrome-see-window.png --json --no-remote
./Apps/CLI/.build/debug/peekaboo see --app "Google Chrome" --path .artifacts/live-e2e/2026-05-07T1118Z/chrome-see-app.png --json --no-remote
./Apps/CLI/.build/debug/peekaboo see --window-id 13665 --path .artifacts/live-e2e/2026-05-07T1118Z/inspector-see-window.png --json --no-remote
./Apps/CLI/.build/debug/peekaboo see --app PeekabooInspector --path .artifacts/live-e2e/2026-05-07T1118Z/inspector-see-app.png --json --no-remote
```

Results:

- permissions granted: Screen Recording, Accessibility, Event Synthesizing;
- display scale: 1x, so Retina 2x behavior remains not reproducible on this host;
- TextEdit `--app` and `--window-id` captured the same `656x422` window; app image wall time improved from `0.72s` to `0.57s`;
- Chrome `--app` and `--window-id` captured the same `1672x1297` window; app image wall time improved from `0.75s` to `0.55s`;
- PeekabooInspector `image --window-id 13665` captured `450x732` in `0.39s`; before the fix, `image --app PeekabooInspector` timed out after `3.30s`, and after the fix it captured the same `450x732` window in `0.57s`;
- `see --app` and `see --window-id` succeeded for TextEdit, Chrome, and PeekabooInspector with matching screenshot dimensions; Inspector `see --app` recorded `84` elements, `74` interactables, and desktop observation spans `state.snapshot=93ms`, `target.resolve=30ms`, `capture.window=155ms`, `detection.ax=129ms`.

Live verification after smart-capture service cleanup, May 7, 2026:

```bash
pnpm run format
pnpm run lint
pnpm run test:safe
./Apps/CLI/.build/debug/peekaboo permissions status --json
./Apps/CLI/.build/debug/peekaboo list apps --json
./Apps/CLI/.build/debug/peekaboo list screens --json
./Apps/CLI/.build/debug/peekaboo list windows --app Finder --json
./Apps/CLI/.build/debug/peekaboo image --mode screen --path /tmp/peekaboo-live-screen.png --json
./Apps/CLI/.build/debug/peekaboo see --app frontmost --path /tmp/peekaboo-live-see-frontmost.png --annotate --json
./Apps/CLI/.build/debug/peekaboo click --coords 500,1000 --no-auto-focus --json
./Apps/CLI/.build/debug/peekaboo move --coords 520,1000 --json
./Apps/CLI/.build/debug/peekaboo see --app TextEdit --path /tmp/peekaboo-live-textedit-before.png --annotate --json
./Apps/CLI/.build/debug/peekaboo click --on elem_2 --snapshot 1ACF34FD-8EA8-4419-B0FA-73689AA4936B --app TextEdit --json
./Apps/CLI/.build/debug/peekaboo type PEEKABOO_LIVE_TYPE_1778155880 --clear --app TextEdit --delay 0 --profile linear --json
./Apps/CLI/.build/debug/peekaboo image --app TextEdit --path /tmp/peekaboo-live-textedit-after.png --json
./Apps/CLI/.build/debug/peekaboo image --app "Google Chrome" --path /tmp/peekaboo-live-chrome-app.png --json
./Apps/CLI/.build/debug/peekaboo image --window-id 12438 --path /tmp/peekaboo-live-chrome-window.png --json
./Apps/CLI/.build/debug/peekaboo see --app "Google Chrome" --path /tmp/peekaboo-live-chrome-see.png --annotate --json
```

Results:

- `pnpm run test:safe` passed `343` tests in `53` suites; `pnpm run lint` found `0` violations;
- permissions granted: Screen Recording, Accessibility, Event Synthesizing;
- `list apps` wall time `0.23s`, `list screens` `0.12s`, `list windows --app Finder` `0.18s`, `list menubar` `0.19s`, `tools` `0.10s`;
- screen capture wrote a nonblank `3008x1632` PNG in `0.54s`; observation capture span `323ms`, output raw write `1.5ms`;
- `see --app frontmost --annotate` on Ghostty produced `241` interactables in `1.09s`; spans included `capture.window=166ms`, `detection.ax=290ms`, `annotation.render=216ms`;
- coordinate `click` and `move` on the already-frontmost Ghostty window succeeded without hitting destructive controls; JSON execution times were `54ms` and `37ms`;
- controlled TextEdit fixture `see` found `393` elements and `301` interactables in `1.06s`; element click targeted `elem_2`, `type --clear` entered `PEEKABOO_LIVE_TYPE_1778155880`, and visual verification confirmed the marker in the captured `656x422` TextEdit image;
- Chrome `image --app` and `image --window-id 12438` both captured the same real `1672x1297` browser window rather than auxiliary `3008x30` or `1x1` windows; app image wall time `0.55s`, window-id wall time `0.83s`;
- Chrome `see --app --annotate` produced `59` elements and `54` interactables in `1.02s`; spans included `capture.window=191ms`, `detection.ax=97ms`, `annotation.render=269ms`;
- screenshots were inspected with local image vision; no blank captures observed.

CLI JSON envelope sweep, May 7, 2026:

```bash
./Apps/CLI/.build/debug/peekaboo permissions status --json
./Apps/CLI/.build/debug/peekaboo list apps --json
./Apps/CLI/.build/debug/peekaboo list screens --json
./Apps/CLI/.build/debug/peekaboo list menubar --json
./Apps/CLI/.build/debug/peekaboo list windows --app Finder --json
./Apps/CLI/.build/debug/peekaboo dock list --json
./Apps/CLI/.build/debug/peekaboo dialog list --json
./Apps/CLI/.build/debug/peekaboo space list --json
./Apps/CLI/.build/debug/peekaboo window list --app Finder --json
./Apps/CLI/.build/debug/peekaboo tools --json
./Apps/CLI/.build/debug/peekaboo commander --json
./Apps/CLI/.build/debug/peekaboo sleep 1 --json
./Apps/CLI/.build/debug/peekaboo image --app frontmost --path /tmp/peekaboo-sweep-frontmost.png --json
./Apps/CLI/.build/debug/peekaboo see --app frontmost --path /tmp/peekaboo-sweep-see.png --json
```

Results:

- `list apps`, `list screens`, and `list windows --app Finder` now use the standard top-level `success/data/debug_logs` envelope instead of the old `data/metadata/summary` shape;
- the documented experimental `commander` diagnostics command is registered again and returns command metadata inside the standard JSON envelope;
- read-only command wall times were `115-235ms` on this host, except `dialog list` returned the expected structured no-dialog error in `164ms`;
- `image --app frontmost` captured successfully in `565ms`; `see --app frontmost` captured and detected successfully in `847ms`.

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
- CLI sources no longer import `AXorcist` or `ScreenCaptureKit`.
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
