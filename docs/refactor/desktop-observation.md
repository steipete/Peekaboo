---
summary: 'Grand refactor plan for unifying Peekaboo screenshot, AX detection, and desktop observation architecture.'
read_when:
  - 'planning major refactors to see, image, capture, or element detection'
  - 'changing screenshot performance, AX traversal, or capture target selection'
  - 'splitting ScreenCaptureService or ElementDetectionService'
  - 'moving CLI capture behavior into AutomationKit'
---

# Desktop Observation Refactor

## Thesis

Peekaboo has several commands that all ask the same question in slightly different ways:

> What is visible on the desktop, where did it come from, and what can I do with it?

Today that behavior is spread across:

- `SeeCommand`
- `ImageCommand`
- MCP `SeeTool`
- MCP `ImageTool`
- `ScreenCaptureService`
- `ElementDetectionService`
- CLI-only bridges such as `ScreenCaptureBridge` and `AutomationServiceBridge`
- ad hoc target selection helpers such as `WindowFilterHelper`

That split makes performance work fragile. A fix for `peekaboo see --app` may not help `image`, MCP, or agent flows. It also forces CLI code to import AppKit, AXorcist, CoreGraphics, and ScreenCaptureKit just to express a user-facing command.

The refactor should make desktop observation a first-class service in `PeekabooAutomationKit`, then make CLI and MCP commands thin adapters.

## Status: May 7, 2026

This plan is now active, not speculative.

Landed:

- `DesktopObservationRequest`, target, capture, detection, output, timeout, timing, and result models.
- `DesktopObservationService` facade in `PeekabooAutomationKit`.
- `ObservationTargetResolver` for core targets.
- `ObservationOutputWriter` for raw screenshot persistence.
- `see`, `image`, MCP `see`, and MCP `image` have first observation-backed paths.
- Request-scoped capture engine preference now flows through observation to `ScreenCaptureService`.
- Observation detection timeout budget is being enforced in the facade.
- Screen capture scale planning is now centralized and unit-tested for logical 1x versus native Retina output.
- Direct `ElementDetectionService` timeout racing is now enforced by `ElementDetectionTimeoutRunner`.

Still intentionally incomplete:

- menubar and menubar popover observation targets;
- annotation output under the observation writer;
- OCR as a first-class observation enhancement;
- structured timing export in all user-facing JSON;
- extraction of `ScreenCaptureService` internals;
- extraction of `ElementDetectionService` internals;
- moving AX traversal policy, descriptor reading, and cache invalidation into dedicated collaborators;
- command cleanup after the bridge paths disappear.

The next work should bias toward small vertical slices that remove duplicated behavior from command code while keeping every commit shippable.

## Grande Refactor Shape

The final architecture should look like this:

```text
CLI / MCP / Agent tools
  parse user input
  map flags or wire input to DesktopObservationRequest
  render typed DesktopObservationResult

PeekabooAutomationKit / Observation
  DesktopObservationService
  ObservationTargetResolver
  CapturePlanner
  CaptureExecutor
  ObservationOutputWriter
  ElementObservationService
  ObservationTracer

PeekabooAutomationKit / Capture
  ScreenCaptureService facade
  ScreenCapturePermissionGate
  ScreenCaptureTargetResolver
  ScreenCapturePlanner
  ScreenCaptureKitOperator
  LegacyScreenCaptureOperator
  ScreenCaptureFallbackRunner
  CaptureImageWriter

PeekabooAutomationKit / Element Detection
  ElementDetectionService facade
  AXTreeCollector
  AXTraversalPolicy
  AXDescriptorReader
  ElementClassifier
  WebFocusFallback
  MenuBarElementCollector
  ElementDetectionCache
  ElementDetectionResultBuilder
```

Command files should become boring adapters. The important policy should move downward into typed services:

- target ranking and window selection live in observation target resolution;
- capture engine, scale, permission, and fallback policy live in capture planning/execution;
- AX traversal, focus fallback, and sparse-web heuristics live in element detection policy;
- file writing, snapshot registration, and annotation output live in observation output;
- JSON/text rendering stays in CLI/MCP layers.

## Architectural Decisions

### Observation Owns User-Visible Target Semantics

`see --app Foo`, `image --app Foo`, MCP `see`, and MCP `image` must resolve to the same window unless the caller explicitly asks otherwise.

This is the right place for:

- visible-window ranking;
- largest non-offscreen window fallback;
- non-empty title preference;
- explicit `--window-id` precedence;
- app name, bundle ID, and PID lookup;
- menubar target resolution.

It is the wrong place for:

- raw ScreenCaptureKit enumeration quirks;
- CLI-specific validation strings;
- output JSON shape.

### Capture Owns Pixels

`ScreenCaptureService` remains the public capture facade while internals are split. Observation can request pixels but should not know whether they came from ScreenCaptureKit, CGWindowList, persistent streams, or a bridge.

Important invariants:

- one screen recording permission check per capture operation;
- one engine preference per request;
- no silent fallback when the user explicitly forced an engine;
- all scale decisions are testable without live display capture;
- `image --retina` maps to native display scale, not to whatever output writer happens to do.

### Detection Owns Accessibility Policy

Observation decides whether detection is needed. Detection decides how AX is traversed.

Move these out of command code and into detection collaborators:

- sparse tree detection;
- web focus fallback thresholds;
- maximum depth and child budgets;
- descriptor batching;
- role classification;
- menu bar element collection;
- cache invalidation.

### Output Writer Owns Files

Commands should not rebuild screenshot paths, raw/annotated path pairs, or snapshot side effects.

Observation output should produce:

- raw screenshot path;
- annotated screenshot path;
- snapshot ID/path metadata;
- image format metadata;
- warnings for skipped output.

Formatting remains outside the writer.

## End-State Blueprint

The full refactor is not just "move code out of commands". The end state is a desktop observation subsystem with explicit state, policies, and diagnostics.

### Canonical Pipeline

Every command or tool that needs to inspect the desktop should use this shape:

```text
User input
  -> request adapter
  -> DesktopObservationRequest
  -> ObservationTargetResolver
  -> DesktopStateSnapshot
  -> CapturePlan
  -> CaptureExecutor
  -> ElementObservationService
  -> ObservationOutputWriter
  -> DesktopObservationResult
  -> CLI/MCP/agent renderer
```

Rules:

- request adapters are allowed to validate user-facing flag combinations;
- adapters are not allowed to rank windows, probe AX, infer capture scale, or write screenshot paths;
- service layers are allowed to return typed diagnostics;
- renderers are allowed to choose JSON/text wording, but not behavior.

### Desktop State Snapshot

Add a request-scoped snapshot object that contains all expensive desktop enumeration results for one observation.

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

This snapshot should be built once per `DesktopObservationService.observe` call and passed to target resolution, capture planning, and diagnostics.

Do not make it a long-lived global cache at first. Most correctness bugs here come from stale windows and stale AX references. Start with request-scoped reuse, then add short TTL caches only where measurements prove value.

### Cache Policy

Use three cache tiers:

- request cache: always allowed, cleared after one observation;
- short TTL cache: allowed for app/window lists and AX trees after live benchmarking;
- persistent cache: only for static metadata such as bundle IDs or command docs, never for live windows/elements.

Initial TTL recommendations:

```text
window inventory: 150-300 ms
frontmost app/window: no TTL unless measured safe
AX element tree: 250-500 ms, keyed by pid + windowID + focus epoch
OCR output: no cache in the first refactor
screenshot pixels: no cache
```

AX cache invalidation triggers:

- different target PID or window ID;
- window bounds changed;
- frontmost app changed;
- click/type/scroll/drag executed;
- focus fallback executed;
- detection options changed, especially web focus fallback and menu bar inclusion;
- timeout/cancellation occurred before traversal completed.

The cache should store immutable detection outputs, not live `AXUIElement` handles. Live AX handles can become invalid and can accidentally keep old UI state alive.

### Desktop Identity Model

Identity types should become explicit enough that CLI/MCP JSON can explain what happened.

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

The same identity should flow through:

- `list windows`;
- `image --app`;
- `image --window-id`;
- `see --app`;
- `see --window-id`;
- MCP `image`;
- MCP `see`;
- snapshots and annotations.

### Target Selection Contract

Automatic app window selection must be deterministic:

1. discard offscreen/minimized/helper-only windows when a renderable alternative exists;
2. prefer explicit `windowID`, then title, then index;
3. for automatic selection, prefer visible titled windows;
4. prefer larger renderable area;
5. break ties by stable CoreGraphics ordering;
6. emit diagnostics for skipped helper windows when verbose/JSON diagnostics are enabled.

This fixes the Tauri/Electron/CEF class of bugs where an app has many toolbar or helper windows and the command grabs a 2560x30 offscreen surface.

### Capture Contract

Capture should have a pure planning layer and a small execution layer.

Pure planner inputs:

- resolved target;
- requested engine;
- requested scale;
- display/window geometry;
- permission intent;
- output format.

Pure planner outputs:

- operation kind;
- engine preference;
- fallback policy;
- native scale;
- output scale;
- expected output pixel size when knowable;
- diagnostics.

Execution owns:

- permission check;
- focus work, if requested;
- ScreenCaptureKit call;
- legacy CoreGraphics call;
- fallback sequencing;
- image conversion.

Hard rules:

- `--retina` means native display scale;
- no command-local scale math;
- no silent engine fallback when the caller forced an engine;
- every capture result reports engine, scale source, native scale, output scale, and final pixel size;
- `screencapture -l <windowID>` remains the behavioral reference for native window capture where macOS allows it.

### Detection Contract

Element detection should become a policy-driven pipeline:

```text
Resolved target
  -> AX root selection
  -> AX traversal policy
  -> descriptor reader
  -> classifier
  -> web focus fallback, if policy says sparse
  -> result builder
  -> snapshot writer
```

Detection should never re-decide app/window selection from scratch when observation already resolved a window. It may resolve AX roots for that window, but the source of truth for target identity is `ResolvedObservationTarget`.

Timeout and cancellation must be real at every public entry point:

- observation callers;
- direct `ElementDetectionService` callers;
- interaction commands that wait for elements;
- MCP calls.

### Interaction Integration

Click/type/scroll/drag are outside the first desktop-observation refactor, but they should consume observation outputs later.

Future shape:

```text
Interaction request
  -> element query
  -> snapshot lookup or observe-if-needed
  -> target point planner
  -> focus/permission guard
  -> action executor
  -> post-action invalidation
```

This makes action commands invalidate AX caches and avoids repeated full-tree scans when a user does `see`, then `click B12`, then `type`.

### Performance Budgets

Budgets are targets, not flaky unit-test thresholds. Record them in manual benchmark notes and structured timings.

Warm local command budget on a normal desktop:

```text
permissions status: <100 ms
list windows --app: <250 ms
image --window-id: <500 ms
image --app: <700 ms
see --window-id, native AX tree: <1500 ms
see --app, native AX tree: <1800 ms
see sparse Chromium/Tauri with focus fallback: <2500 ms
```

Performance failures to treat as bugs:

- `image` instantiates or traverses element detection;
- `see --window-id` traverses all windows for an app when a direct window context exists;
- local commands probe bridge or remote endpoints by default;
- permission checks happen twice in one command;
- fallback focus runs after a rich native tree was already found;
- command runtime spends meaningful time formatting JSON compared with capture/detection.

### CLI Consistency Contract

The refactor should remove CLI drift. For equivalent flags:

- `image --app X` and `see --app X` resolve the same target;
- `image --window-id N` and `see --window-id N` report the same window identity;
- CLI and MCP share target resolution;
- JSON uses the same identity names for app/window metadata;
- errors use the same typed reason for target-not-found, permission-denied, unsupported-target, and timeout;
- `--verbose` reveals diagnostics without changing behavior.

Backwards compatibility is not sacred for inconsistent behavior. If old behavior selected helper windows, ignored `--retina`, or hid timeouts, fix it and call it out in the changelog.

### Module Boundary Contract

Do not split packages until the behavior boundary is stable. When extraction is ready, the dependency direction should be:

```text
PeekabooCLI
  -> PeekabooAgentRuntime
  -> PeekabooObservation
  -> PeekabooCapture
  -> PeekabooElementDetection
  -> PeekabooFoundation
```

No lower-level module should depend on CLI, MCP, Tachikoma, Commander, or renderer-specific JSON.

## Ship Groups

### Group 0: Stabilize Current Observation Slice

Purpose: make the already-landed facade hard to regress.

Work:

- finish detection timeout enforcement;
- add focused tests for engine preference, output path writing, and detection timeout;
- ensure `see`, `image`, MCP `see`, and MCP `image` all use the observation path for supported targets;
- keep unsupported targets explicit instead of silently falling back.

Gate:

```bash
swift test --package-path Core/PeekabooAutomationKit --filter DesktopObservationServiceTests
pnpm run lint
pnpm run test:safe
```

### Group 1: Target Resolver Becomes Canonical

Purpose: kill duplicate target/window selection behavior.

Work:

- migrate remaining app/window ranking from `ImageCommand`, `SeeCommand`, and MCP tools into `ObservationTargetResolver`;
- add ranking tests for Tauri/Electron-style auxiliary windows;
- prefer largest visible non-offscreen window when no title/index/window ID is supplied;
- preserve explicit title/index/window ID behavior;
- expose diagnostics when automatic selection skips helper windows.

Gate:

```bash
swift test --package-path Core/PeekabooAutomationKit --filter ObservationTargetResolverTests
pnpm run test:safe
```

Manual checks:

```bash
peekaboo list windows --app "Zephyr Agency" --json-output
peekaboo image --app "Zephyr Agency" --path /tmp/zephyr.png --json-output
peekaboo see --app "Zephyr Agency" --json-output
```

Expected: `image --app` and `see --app` choose the same main window, not a 2560x30 auxiliary window.

### Group 2: Retina and Scale Policy

Purpose: make 1x versus native scale impossible to drift.

Work:

- move scale planning into a pure planner;
- test logical 1x versus native scale at planner level;
- verify `image --retina` produces native pixels for window capture;
- verify `image` without `--retina` keeps logical output where intended;
- add diagnostics for actual output pixel size and scale source.

Gate:

```bash
swift test --package-path Core/PeekabooCore --filter ScreenCaptureServiceFlowTests
swift test --package-path Core/PeekabooCore --filter CaptureEngineResolverTests
pnpm run test:safe
```

Manual check:

```bash
peekaboo image --window-id <id> --path /tmp/no-retina.png --json-output
peekaboo image --window-id <id> --retina --path /tmp/retina.png --json-output
sips -g pixelWidth -g pixelHeight /tmp/no-retina.png /tmp/retina.png
```

Expected: native capture is 2x on Retina displays when the backing display scale is 2.0.

### Group 3: Menubar Observation

Purpose: remove the last special-case capture island from `see`.

Work:

- support `.menubar` in `ObservationTargetResolver`;
- support `.menubarPopover(hints:)`;
- route existing menubar area capture through observation;
- route menubar OCR through observation output/timing;
- keep click-to-open behavior outside observation unless it becomes a formal interaction pipeline.

Gate:

```bash
swift test --package-path Core/PeekabooAutomationKit --filter DesktopObservationServiceTests
pnpm run test:safe
```

Manual checks:

```bash
peekaboo see --mode menubar --json-output --verbose
peekaboo see --mode menu --app Finder --json-output --verbose
```

### Group 4: Annotation and OCR Output

Purpose: unify screenshot-derived artifacts.

Work:

- add observation output options for annotations and OCR;
- move raw/annotated file pair creation into `ObservationOutputWriter`;
- attach annotation/OCR timings to `ObservationTimings`;
- keep Tachikoma/AI analysis above AutomationKit unless dependencies are split first.

Gate:

```bash
pnpm run test:safe
```

Manual checks:

```bash
peekaboo see --window-id <id> --annotate --path /tmp/see.png --json-output
peekaboo see --window-id <id> --json-output --verbose
```

### Group 5: Split Capture Internals

Purpose: make capture fast, testable, and small enough to reason about.

Work:

- extract permission gate;
- extract capture planner;
- extract target resolver helpers;
- extract scale resolver if not already isolated;
- split ScreenCaptureKit and legacy operators;
- keep `ScreenCaptureService` as a facade;
- remove direct `ScreenCaptureKit` imports from command files.

Gate:

```bash
swift test --package-path Core/PeekabooCore --filter ScreenCaptureService
swift test --package-path Core/PeekabooCore --filter CaptureEngineResolverTests
pnpm run test:safe
```

Acceptance:

- `ScreenCaptureService.swift` under about 500 lines;
- planner tests do not need screen recording permission;
- capture engine forcing is covered by tests;
- no command imports `ScreenCaptureKit`.

### Group 6: Split Element Detection Internals

Purpose: isolate AX traversal policy and performance-sensitive code.

Work:

- extract `AXTraversalPolicy`;
- extract `AXTreeCollector`;
- extract `AXDescriptorReader`;
- extract `ElementClassifier`;
- extract `WebFocusFallback`;
- extract `MenuBarElementCollector`;
- add pure tests for fallback thresholds;
- add cancellation/timeout tests for direct detection callers.

Gate:

```bash
swift test --package-path Core/PeekabooAutomationKit --filter ElementDetectionServiceTests
pnpm run test:safe
```

Acceptance:

- `ElementDetectionService.swift` under about 500 lines;
- rich native trees skip web focus fallback;
- sparse Chromium/Tauri trees can still trigger fallback;
- direct `ElementDetectionService` callers have a real timeout, not just observation callers.

### Group 7: Structured Timings Everywhere

Purpose: performance debugging without scraping log prose.

Work:

- expose `ObservationTimings` in CLI JSON for `see` and `image`;
- expose the same spans in MCP metadata;
- add metadata for engine, target kind, window ID, output scale, and element count;
- standardize span names;
- add lightweight manual benchmark docs.

Gate:

```bash
pnpm run test:safe
```

Manual benchmark:

```bash
/usr/bin/time -p peekaboo image --window-id <id> --path /tmp/image.png --json-output
/usr/bin/time -p peekaboo see --window-id <id> --json-output --verbose
```

### Group 8: Command Cleanup and Module Boundaries

Purpose: make CLI/MCP boring and prepare later module extraction.

Work:

- delete obsolete bridge helpers from command files;
- move request mapping into small command support types;
- keep command files below target sizes;
- archive old refactor notes that no longer apply;
- update command docs for changed diagnostics/timing fields.

Gate:

```bash
pnpm run lint
pnpm run format
pnpm run test:safe
```

Acceptance:

- `SeeCommand.swift` under about 400 lines;
- `ImageCommand.swift` under about 400 lines;
- command files do not import `AXorcist` or `ScreenCaptureKit`;
- `see`, `image`, MCP `see`, and MCP `image` share target resolution and output metadata.

## Goals

- One canonical pipeline for screenshot capture plus optional AX detection.
- One canonical target model for screen, window, app, PID, frontmost, area, menubar, and window ID.
- One canonical target resolver shared by CLI, MCP, and agent tools.
- One canonical timing/trace model, no parsing human log lines to benchmark.
- Keep hot paths fast: no extra bridge probes, TCC probes, AX tree walks, or app focus work.
- Keep behavior observable and testable without launching the full CLI.
- Split large services behind stable facades instead of rewriting everything at once.
- Move platform details out of command files.
- Preserve existing public command behavior unless a behavior is clearly inconsistent or buggy.

## Non-Goals

- Do not start with package/module extraction. Behavioral boundaries must be cleaned up first.
- Do not redesign all automation actions. Click/type/scroll can consume observation results later.
- Do not move Peekaboo-specific heuristics into AXorcist. AXorcist stays a lean AX toolkit.
- Do not add an async abstraction layer around every AX call. Use async only around real waits and cancellation.
- Do not make the CLI the source of truth for capture or detection policy.

## Current Problems

### Command-Level Orchestration

`SeeCommand` currently owns target interpretation, capture mode selection, menu bar special cases, screenshot saving, AX detection, annotation, timeout handling, and output shaping.

`ImageCommand` repeats a similar capture target flow, but with different output and scale behavior.

MCP tools perform their own target parsing and context creation again.

This creates three failure modes:

- performance fixes land in one path only;
- command options drift from service capabilities;
- tests target adapters instead of the shared behavior.

### Large Service Types

The largest service files are doing too many jobs:

- `ScreenCaptureService.swift`: capture planning, permissions, app/window resolution, engine fallback, focus handling, file output details, and engine-specific work.
- `ElementDetectionService.swift`: app/window resolution, AX traversal, descriptor reads, role classification, fallback focus policy, caching, menu bar extraction, and snapshot output.

These services should remain the public facades, but their internals need extracted collaborators.

### Target Selection Is Duplicated

The same concepts appear as command options, MCP strings, service method overloads, `CaptureTarget`, `WindowContext`, `WindowFilterHelper`, and CoreGraphics window IDs.

There should be one request type and one resolved target type.

### Timings Are Not Structured

The CLI logs useful timings, but benchmarking currently requires scraping debug log strings such as `Timer 'element_detection' completed`.

The observation pipeline should produce structured spans:

```swift
public struct ObservationTimings: Sendable, Codable, Equatable {
    public var spans: [ObservationSpan]
}

public struct ObservationSpan: Sendable, Codable, Equatable {
    public var name: String
    public var durationMS: Double
    public var metadata: [String: String]
}
```

## Target Architecture

### New Facade

Add a high-level service in `PeekabooAutomationKit`:

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

This service becomes the single owner of:

- target resolution;
- capture planning;
- capture execution;
- optional file persistence;
- optional element detection;
- optional OCR preference;
- optional annotation metadata;
- timing collection;
- capture/detection timeout policy.

The service should not format CLI output. It returns typed data.

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

### Target Request

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

Keep `CGWindowID` here only if the module already imports CoreGraphics. If this becomes a pure model module later, wrap it as:

```swift
public struct WindowID: RawRepresentable, Sendable, Codable, Equatable, Hashable {
    public var rawValue: UInt32
}
```

### Resolved Target

```swift
public struct ResolvedObservationTarget: Sendable, Equatable {
    public var kind: ResolvedObservationKind
    public var app: ApplicationIdentity?
    public var window: WindowIdentity?
    public var bounds: CGRect?
    public var detectionContext: WindowContext?
    public var captureScaleHint: CGFloat?
}
```

The resolved target is the only place where app/window selection policy should live.

### Capture Options

```swift
public struct DesktopCaptureOptions: Sendable, Equatable {
    public var engine: CaptureEnginePreference
    public var scale: CaptureScalePreference
    public var focus: CaptureFocus
    public var visualizerMode: CaptureVisualizerMode
    public var includeMenuBar: Bool
}
```

This should reuse existing enums where possible.

### Detection Options

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

Default behavior:

- `image`: `.none`
- `see`: `.accessibility`
- menubar popover capture: `.accessibilityAndOCR` or OCR-preferred when AX is not meaningful
- analyze-only image flow: `.none` unless the caller asks for UI map

### Output Options

```swift
public struct DesktopObservationOutputOptions: Sendable, Equatable {
    public var path: String?
    public var format: ImageFormat
    public var saveRawScreenshot: Bool
    public var saveAnnotatedScreenshot: Bool
    public var snapshotID: String?
}
```

The service may save files and snapshots, but it should not print.

### Result Model

```swift
public struct DesktopObservationResult: Sendable {
    public var target: ResolvedObservationTarget
    public var capture: CaptureResult
    public var elements: ElementDetectionResult?
    public var files: DesktopObservationFiles
    public var timings: ObservationTimings
    public var diagnostics: DesktopObservationDiagnostics
}
```

`CaptureResult` can stay as-is initially. Later, flatten it into a more explicit `CapturedImage` if needed.

## Internal Pipeline

`DesktopObservationService.observe` should be explicit and boring:

```swift
public func observe(_ request: DesktopObservationRequest) async throws -> DesktopObservationResult {
    try await self.tracer.trace("desktop.observe") {
        let target = try await self.targetResolver.resolve(request.target)
        let plan = try self.capturePlanner.plan(target: target, options: request.capture)
        let capture = try await self.captureExecutor.capture(plan)
        let files = try await self.outputWriter.write(capture, options: request.output)
        let elements = try await self.detectIfNeeded(capture, target: target, options: request.detection)
        return self.resultBuilder.build(...)
    }
}
```

Keep each step separately testable.

## New Collaborators

### `ObservationTargetResolver`

Owns target lookup and ranking:

- app name, bundle ID, `PID:123`, explicit PID;
- frontmost app/window;
- `--window-id`;
- window title/index;
- largest visible window fallback;
- menubar and menu extra popover windows;
- offscreen/minimized/window-level filtering.

Input:

```swift
DesktopObservationTargetRequest
```

Output:

```swift
ResolvedObservationTarget
```

Existing logic to migrate:

- `ImageCommand.determineMode`
- `ImageCommand.captureApplicationWindow`
- `ImageCommand.captureAllApplicationWindows`
- `SeeCommand.performStandardCapture`
- `SeeTool.parseCaptureTarget`
- `SeeTool.windowContext`
- `WindowFilterHelper.filter`
- CoreGraphics-only window fast path recently added for `image --app`

### `CapturePlanner`

Converts a resolved target plus capture options into a concrete engine plan:

```swift
public struct CapturePlan: Sendable {
    public var operation: CaptureOperation
    public var target: ResolvedObservationTarget
    public var engine: CaptureEnginePreference
    public var scale: CaptureScalePreference
    public var focus: CaptureFocus
    public var permissionMode: CapturePermissionMode
}
```

This is where duplicate TCC preflights must stay eliminated.

### `CaptureExecutor`

Calls the existing `ScreenCaptureService` facade at first. After the facade is split, it can call lower-level engines directly.

Do not make this type format paths or output JSON.

### `ObservationOutputWriter`

Owns:

- default screenshot paths;
- format conversion;
- raw screenshot path;
- annotated screenshot path handoff;
- snapshot path registration.

It should replace duplicated file path generation in `image`, `see`, and MCP.

### `ElementObservationService`

Thin wrapper around `ElementDetectionService` that accepts capture metadata and detection options.

It should be responsible for:

- passing `WindowContext`;
- deciding whether AX detection should run;
- preserving `allowWebFocusFallback`;
- attaching timings;
- returning nil for `.none`.

### `ObservationTracer`

Structured timings:

```swift
public protocol ObservationTracing: Sendable {
    func span<T>(
        _ name: String,
        metadata: [String: String],
        operation: () async throws -> T
    ) async rethrows -> T
}
```

Implementation can be a tiny actor or a main-actor object because most work is main-actor bound.

Required span names:

- `target.resolve`
- `permission.screen-recording`
- `focus.window`
- `capture.window`
- `capture.screen`
- `capture.area`
- `capture.write-file`
- `detection.ax`
- `detection.ocr`
- `snapshot.write`
- `annotation.render`
- `desktop.observe`

## Refactor Phases

### Phase 0: Baseline and Characterization

Before changing architecture, capture baselines:

```bash
pnpm run lint
pnpm run test:safe
swift test --package-path Core/PeekabooCore --filter ElementDetectionTraversalPolicyTests
```

Live performance baselines:

```bash
Apps/CLI/.build/debug/peekaboo list windows --app Playground --json-output
Apps/CLI/.build/debug/peekaboo image --window-id <id> --path /tmp/peekaboo-window.png --json-output
Apps/CLI/.build/debug/peekaboo see --window-id <id> --json-output --verbose
Apps/CLI/.build/debug/peekaboo see --window-id <id> --json-output --verbose --no-web-focus
```

Record:

- process wall time;
- structured command timer if available;
- capture duration;
- detection duration;
- element count;
- interactable count;
- screenshot pixel dimensions.

Acceptance:

- no code changes;
- numbers added to the PR description or a temporary local note;
- no new tests yet.

### Phase 1: Introduce Observation Models and Facade

Add files under:

```text
Core/PeekabooAutomationKit/Sources/PeekabooAutomationKit/Services/Observation/
```

Suggested files:

```text
DesktopObservationService.swift
DesktopObservationModels.swift
DesktopObservationTracing.swift
ObservationTargetResolver.swift
CapturePlanner.swift
ObservationOutputWriter.swift
ElementObservationService.swift
```

Initial implementation may delegate back to existing services.

Rules:

- no command behavior changes;
- no broad file moves;
- keep old public service APIs;
- add tests for request mapping and target resolution policy.

Acceptance:

- `DesktopObservationService.observe` can execute a window screenshot with detection in tests using stubs;
- no CLI command uses it yet;
- `pnpm run test:safe` passes.

### Phase 2: Port `see` to `DesktopObservationService`

Rewrite `SeeCommand` so it:

- parses CLI flags;
- creates `DesktopObservationRequest`;
- calls `services.desktopObservation.observe(request)`;
- formats the result.

Move these out of `SeeCommand`:

- `ScreenCaptureBridge`;
- standard capture selection;
- detection timeout calculation if it is service policy;
- `WindowContext` construction;
- raw screenshot output path handling.

Keep in `SeeCommand`:

- Commander option declarations;
- JSON/text output;
- analyze prompt handling if it remains CLI-specific;
- annotation presentation flags, until annotation is moved.

Acceptance:

- existing `SeeCommand` tests pass;
- live `see --window-id` output is equivalent;
- live `see --app Playground` does not include sibling-window elements;
- performance is no worse than baseline by more than 5 percent after warmup.

### Phase 3: Port `image` to the Same Pipeline

Rewrite `ImageCommand` around `DesktopObservationRequest` with `detection.mode = .none`.

Move these out of `ImageCommand`:

- `determineMode`;
- per-target capture methods;
- app/window selection;
- screenshot file writing;
- scale selection beyond mapping `--retina` to `.native`.

Keep in `ImageCommand`:

- output formatting;
- AI image analysis prompt;
- command validation messages.

Acceptance:

- `image --window-id` works;
- `image --app` uses the same largest-visible-window policy as `see`;
- `--retina` behavior stays explicit and tested;
- `image` and `see` target the same window for the same app/window flags.

### Phase 4: Port MCP `SeeTool` and `ImageTool`

Replace MCP target parsing with `DesktopObservationTargetRequest`.

Do not keep a separate MCP target grammar unless the wire protocol requires it. If the MCP input format is string-based, parse once into the shared request type.

Acceptance:

- MCP `see` and CLI `see` produce equivalent target resolution;
- MCP `image` and CLI `image` produce equivalent target resolution;
- no MCP-only screenshot code remains except response formatting.

### Phase 5: Split `ScreenCaptureService`

Keep `ScreenCaptureService` as the public facade, but extract implementation:

```text
Services/Capture/Planning/
  ScreenCapturePermissionGate.swift
  ScreenCapturePlanner.swift
  ScreenCaptureTargetResolver.swift
  CaptureScaleResolver.swift

Services/Capture/Engines/
  ScreenCaptureKitOperator.swift
  LegacyScreenCaptureOperator.swift
  ScreenCaptureFallbackRunner.swift

Services/Capture/Output/
  CaptureImageWriter.swift
  CaptureMetadataBuilder.swift
```

Current nested/private logic should become small internal types with focused tests.

Hard rules:

- permission checks happen exactly once per capture operation;
- engine fallback remains controlled by `PEEKABOO_CAPTURE_ENGINE`;
- no command imports ScreenCaptureKit directly;
- `ScreenCaptureService` stays source-compatible while the migration happens.

Acceptance:

- `ScreenCaptureService.swift` drops below about 500 lines;
- public protocol remains stable or changes in one deliberate migration;
- capture tests cover planner decisions without screen permissions;
- live capture performance remains within baseline.

### Phase 6: Split `ElementDetectionService`

Keep `ElementDetectionService` as facade, extract:

```text
Services/UI/ElementDetection/
  AXTreeCollector.swift
  AXTraversalPolicy.swift
  AXDescriptorReader.swift
  ElementClassifier.swift
  ElementDetectionCache.swift
  WebFocusFallback.swift
  MenuBarElementCollector.swift
  ElementDetectionResultBuilder.swift
```

Ownership:

- `AXTreeCollector`: tree walk only;
- `AXTraversalPolicy`: depth, child count, fallback thresholds, role skip policy;
- `AXDescriptorReader`: batched AX attribute reads;
- `ElementClassifier`: role, label, enabled/actionable/interactable;
- `WebFocusFallback`: Chromium/Tauri focus probing;
- `ElementDetectionCache`: TTL and invalidation;
- `ResultBuilder`: snapshot and element ID map.

The recent fallback policy should move from `ElementDetectionService.shouldAttemptWebFocusFallback` into `AXTraversalPolicy`.

Acceptance:

- `ElementDetectionService.swift` drops below about 500 lines;
- traversal policy has pure unit tests;
- descriptor reader has tests for batched reads with fake elements if feasible;
- live Playground detection remains around current baseline;
- Tauri/Chromium sparse tree fallback remains covered by a targeted test or manual repro note.

### Phase 7: Unify Annotation and OCR

Today annotation and OCR are partly command behavior. Move their pipeline decisions under observation, while keeping output formatting in commands.

Add:

```swift
public enum ObservationEnhancement: Sendable, Equatable {
    case annotation
    case ocr
    case aiAnalysis(prompt: String)
}
```

AI analysis may stay above AutomationKit if it pulls in Tachikoma. If so, observation should expose clean screenshot and OCR inputs for the agent layer.

Acceptance:

- `see --annotate` is backed by result metadata, not command-local capture assumptions;
- menubar OCR uses the same output writer and trace spans;
- no duplicate coordinate conversion logic.

### Phase 8: Module Extraction After Boundaries Are Stable

Only after phases 1-7 should module splitting resume.

Recommended extraction order:

1. `PeekabooObservation` or `PeekabooDesktopObservation`
2. `PeekabooCapture`
3. `PeekabooElementDetection`
4. command package split

Do not extract modules while behavior is still duplicated. It will freeze the wrong boundaries.

## CLI Migration Shape

After the migration, command files should look like this:

```swift
@MainActor
mutating func run(using runtime: CommandRuntime) async throws {
    self.runtime = runtime
    let request = try self.makeObservationRequest()
    let result = try await runtime.services.desktopObservation.observe(request)
    try await self.render(result)
}
```

Command files should not import:

- `AXorcist`
- `ScreenCaptureKit`
- `CoreGraphics`, except for simple coordinate parsing until wrappers exist
- `AppKit`, unless output code truly needs it

Expected remaining imports:

- `Commander`
- `Foundation`
- `PeekabooCore` or narrower modules after extraction
- `PeekabooFoundation`

## Service Container Changes

Add observation service to `PeekabooServiceProviding`:

```swift
@MainActor
public protocol PeekabooServiceProviding {
    var desktopObservation: any DesktopObservationServiceProtocol { get }
}
```

Wire it in:

- `PeekabooServices`
- `RemotePeekabooServices`, if bridge support needs a remote observation endpoint
- tests/stubs

Decision point:

- Option A: expose observation over bridge as one high-level request.
- Option B: keep bridge endpoints as capture and detect primitives.

Recommendation: start with Option B to keep network/API churn low. Add high-level bridge observation only after CLI and MCP are stable.

## Testing Strategy

### Pure Unit Tests

Add tests for:

- CLI options to `DesktopObservationRequest`;
- MCP input to `DesktopObservationRequest`;
- target resolver ranking;
- offscreen/minimized filtering;
- largest visible window fallback;
- `--window-id` precedence;
- `--retina` to `CaptureScalePreference.native`;
- detection mode selection;
- web focus fallback policy;
- trace span emission.

### Stubbed Integration Tests

Use fake services:

- fake app/window inventory;
- fake capture executor returning deterministic image data;
- fake detector returning deterministic elements;
- fake output writer returning deterministic paths.

These should verify:

- `see` calls detection;
- `image` does not call detection;
- menubar capture sets OCR preference;
- annotations request annotation output;
- timeout settings flow through.

### Live Tests

Keep a small manually runnable script or documented command set:

```bash
Apps/CLI/.build/debug/peekaboo permissions status --json-output
Apps/CLI/.build/debug/peekaboo list windows --app Playground --json-output
Apps/CLI/.build/debug/peekaboo image --window-id <id> --path /tmp/image.png --json-output
Apps/CLI/.build/debug/peekaboo image --window-id <id> --retina --path /tmp/image-retina.png --json-output
Apps/CLI/.build/debug/peekaboo see --window-id <id> --json-output --verbose
Apps/CLI/.build/debug/peekaboo see --app Playground --json-output --verbose
```

For each live run record:

- wall time;
- structured `desktop.observe`;
- capture span;
- detection span;
- element count;
- screenshot dimensions;
- target title/window ID.

### Performance Guards

Add a non-flaky test for policy, not absolute time:

- no bridge probe for local read-only observation unless `--bridge-socket` is set;
- no duplicate screen recording preflight;
- no web focus fallback when native tree is rich;
- no app-root AX traversal for a window capture;
- `image` does not instantiate element detection.

Absolute timing belongs in manual benchmark docs or opt-in performance tests.

## Risk Areas

### Menubar Capture

Menubar popovers mix window list, OCR, area fallback, and click-to-open behavior. Keep this as a sub-pipeline under observation, not as the first migrated path.

Migration order:

1. normal window;
2. screen/frontmost;
3. app/window selection;
4. menubar area;
5. menubar popover.

### Retina Scale

`image --retina` has a concrete bug history. Add explicit tests that compare logical vs native scale decisions at the planning layer.

Do not infer Retina behavior from output path code.

### Tauri/Electron/Chromium

The web focus fallback exists because some apps expose sparse AX trees until web content is focused.

Keep the current policy:

- skip fallback when text fields are visible;
- skip fallback when a rich native tree is already present;
- allow fallback for sparse trees.

Move thresholds into `AXTraversalPolicy`.

### Bridge and Remote

Bridge APIs already expose capture and detect primitives. Do not force the bridge to understand the full observation request in the first pass.

If local CLI uses observation but remote CLI does not, behavior can drift. Add parity tests for request mapping so a future remote observation endpoint is straightforward.

### Snapshot Compatibility

The observation result should preserve snapshot behavior:

- same snapshot JSON shape unless deliberately migrated;
- same element IDs for equivalent captures as much as possible;
- annotated screenshot paths stored the same way.

## Rollout Plan

Recommended commit grouping:

1. `refactor(observation): add desktop observation models`
2. `refactor(observation): add target resolver`
3. `refactor(observation): add observation service facade`
4. `refactor(see): route through desktop observation`
5. `refactor(image): route through desktop observation`
6. `refactor(mcp): route screenshot tools through desktop observation`
7. `refactor(capture): split capture planning from execution`
8. `refactor(capture): split capture output writing`
9. `refactor(ax): extract traversal policy and collector`
10. `refactor(ax): extract descriptor reader and classifier`
11. `perf(observation): add structured spans`
12. `docs(observation): document new pipeline and migration notes`

Keep each commit shippable. The facade can coexist with old command code while migration is in progress.

## Acceptance Criteria For The Whole Refactor

- `SeeCommand.swift` is under about 400 lines.
- `ImageCommand.swift` is under about 400 lines.
- `ScreenCaptureService.swift` is under about 500 lines.
- `ElementDetectionService.swift` is under about 500 lines.
- CLI command files no longer import `AXorcist` or `ScreenCaptureKit`.
- `see`, `image`, MCP `see`, and MCP `image` share target resolution.
- `image` and `see` choose the same app window for equivalent target flags.
- structured timings are available in JSON/debug output.
- no duplicated screen recording preflight.
- no default bridge probe for local read-only commands.
- no app-root AX traversal for a window capture.
- rich native AX trees skip web focus fallback.
- sparse web AX trees can still use web focus fallback.
- `pnpm run lint` passes.
- `pnpm run test:safe` passes.
- targeted Core observation tests pass.
- live Playground benchmark is no worse than current baseline.

## Open Questions

- Should observation become a bridge endpoint once local behavior is stable?
- Should AI image analysis become an observation enhancement, or stay in agent/CLI layers because it depends on Tachikoma?
- Should `CaptureTarget` be replaced by `DesktopObservationTargetRequest`, or should the new request wrap the old enum?
- Should screenshot file writing remain in AutomationKit, or should services return image data and let apps write files?
- Should OCR move out of CLI helpers into AutomationKit during this refactor, or wait until after `see` and `image` are unified?

## Recommended First PR

Start with the smallest useful architecture PR:

- Add `DesktopObservationModels.swift`.
- Add `DesktopObservationService` facade.
- Add `ObservationTargetResolver` with only `.windowID`, `.frontmost`, `.screen`, and `.app(..., .automatic)`.
- Add stubbed tests for request mapping and target resolution.
- Do not port `see` yet.

The second PR should port `see --window-id` only. That gives a narrow vertical slice with real capture and detection before touching the complex app and menubar paths.
