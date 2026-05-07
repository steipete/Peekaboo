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

