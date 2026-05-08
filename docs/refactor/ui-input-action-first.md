---
summary: 'Full refactor plan for making Peekaboo UI input action-first with synthetic-event fallback, so CGEvent paths become optional instead of mandatory.'
read_when:
  - 'changing ClickService, ScrollService, TypeService, HotkeyService, or InputDriver'
  - 'adding AX action invocation, direct value setting, or generic element actions'
  - 'changing MCP click, type, scroll, hotkey, set_value, or perform_action behavior'
  - 'debugging stale coordinate clicks, cursor warping, secure input, or background UI automation'
  - 'planning per-app input overrides, input-path logging, or interaction snapshot freshness rules'
---

# UI Input Action-First Refactor

## Thesis

Peekaboo should treat low-level synthetic input as a fallback, not the only way to drive the UI.

Today most interaction flows eventually collapse to a screen point and call the synthetic input stack. That keeps behavior universal, but it also means routine element-targeted actions inherit the worst properties of coordinate input: cursor warping, frontmost-app requirements, stale-coordinate bugs, secure-input dropouts, and harder permission optics.

The desired shape is dual-mode:

```text
agent / CLI / MCP request
  -> typed interaction target
  -> fresh element resolution when available
  -> action invocation path
  -> synthetic input fallback when action invocation is unsupported
  -> execution metadata + debug log + visualizer anchor
```

Do not delete synthetic input. Drag paths, force click, canvas-style interactions, accessibility-blind apps, global shortcuts, and non-menu hotkeys still need synthesis. The goal is expanded options and better defaults, not ideological replacement.

## Terminology

Use product-neutral names in new code:

- `action`: invoke an accessibility action or set an accessibility value on an element.
- `synth`: synthesize lower-level mouse or keyboard input.
- `actionFirst`: try action, fall back to synth.
- `synthFirst`: current behavior; synth is primary.
- `actionOnly`: diagnostic / parity / no-synthetic-input mode.
- `synthOnly`: current behavior locked; escape hatch for hard apps.

Avoid naming the policy around `AX` versus `CGEvent`. AXorcist is already the perception/action substrate, and future synthesis may include public CGEvent posting, virtual HID, or other backends.

## Current State

### Service Wiring

`UIAutomationService` builds concrete input services directly:

- `ClickService`
- `TypeService`
- `ScrollService`
- `HotkeyService`
- `GestureService`

Relevant files:

- `Core/PeekabooAutomationKit/Sources/PeekabooAutomationKit/Services/UI/UIAutomationService.swift`
- `Core/PeekabooAutomationKit/Sources/PeekabooAutomationKit/Services/UI/UIAutomationService+Operations.swift`
- `Core/PeekabooAutomationKit/Sources/PeekabooAutomationKit/Services/UI/UIAutomationService+PointerKeyboardOperations.swift`
- `Core/PeekabooAutomationKit/Sources/PeekabooAutomationKit/Services/UI/UIAutomationService+TypingOperations.swift`

Public service methods mostly return simple success values or existing DTOs. They do not return the input path chosen, fallback reason, action name, or visualizer anchor. That metadata needs to exist internally before defaults can flip safely.

### Current Synthetic Paths

Click:

- `ClickService` resolves element/query/coordinates to a point.
- It adjusts window-relative points.
- It calls `InputDriver.click(at:)`.
- Text-field clicking includes focus/nudge behavior that action/value paths should avoid.

Scroll:

- `ScrollService` resolves element targets to a point.
- It moves the mouse to the point.
- It calls `InputDriver.scroll(...)`.

Type:

- `TypeService.type(text:target:...)` clicks a target, then types.
- `TypeService.typeActions(...)` synthesizes text and special keys.
- Direct value setting is a separate semantic operation, not a full replacement for `typeActions`.

Hotkey:

- `HotkeyService` uses `InputDriver.hotkey(...)` for foreground chords.
- Targeted background hotkeys use CGEvent posting to a PID.
- There is no menu-item shortcut resolution path yet.

Gesture:

- Drag, swipe, and move are synthesis-only by nature.
- Keep them out of the action-first default flip.

### MCP Tool Surface

The MCP layer currently hides element intent in some paths:

- `ClickTool` resolves element IDs to coordinates itself, then calls automation with `.coordinates`.
- `TypeTool` focus-clicks by coordinate before typing.
- `ScrollTool` already passes target element IDs through.
- `HotkeyTool` can stay service-backed.

Files:

- `Core/PeekabooCore/Sources/PeekabooAgentRuntime/MCP/Tools/ClickTool.swift`
- `Core/PeekabooCore/Sources/PeekabooAgentRuntime/MCP/Tools/TypeTool.swift`
- `Core/PeekabooCore/Sources/PeekabooAgentRuntime/MCP/Tools/ScrollTool.swift`
- `Core/PeekabooCore/Sources/PeekabooAgentRuntime/MCP/Tools/HotkeyTool.swift`
- `Core/PeekabooCore/Sources/PeekabooAgentRuntime/MCP/Tools/UISnapshotStore.swift`

Action-first cannot work reliably until MCP tools preserve element-targeted intent instead of lowering early to coordinates.

### Snapshot and Element Data

Snapshots store serializable `UIElement` values, not raw AX handles:

- `Core/PeekabooAutomationKit/Sources/PeekabooAutomationKit/Core/Models/Snapshot.swift`
- `Core/PeekabooAutomationKit/Sources/PeekabooAutomationKit/Services/Support/SnapshotManager.swift`
- `Core/PeekabooAutomationKit/Sources/PeekabooAutomationKit/Services/Support/SnapshotManager+Helpers.swift`

That is good. Do not persist raw AX handles across turns. Instead, resolve a fresh action-capable element from the latest snapshot context when acting.

Current snapshot elements include role, title, label/value/description/help, identifier, frame, actionable flag, and keyboard shortcut. Action-first needs more optional metadata:

- advertised action names
- whether value is settable
- better name fallback
- focused/enabled/offscreen flags when cheap
- enough context to re-find the element in the target app/window

### AXorcist Support

AXorcist already has the raw operations needed:

- `AXorcist/Sources/AXorcist/Core/Element.swift`
- `AXorcist/Sources/AXorcist/Core/Element+Actions.swift`
- `AXorcist/Sources/AXorcist/Core/AXError+Extensions.swift`

Important caveat: existing AXorcist action handlers validate advertised action support before invoking. The new action driver should not rely only on advertised actions. Some elements perform actions they do not advertise; some advertise actions that no-op. Try the action, classify the error, and fall back when appropriate.

### Bridge Surface

The bridge already centralizes permissioned automation behind a host:

- `Core/PeekabooCore/Sources/PeekabooBridge/PeekabooBridgeRequestResponse.swift`
- `Core/PeekabooCore/Sources/PeekabooBridge/PeekabooBridgeModels.swift`
- `Core/PeekabooCore/Sources/PeekabooBridge/PeekabooBridgeServer+Handlers.swift`
- `Core/PeekabooCore/Sources/PeekabooBridge/PeekabooBridgeServer+Handshake.swift`
- `Core/PeekabooCore/Sources/PeekabooBridge/PeekabooBridgeClient.swift`

New agent-visible operations such as `setValue` and `performAction` need bridge request/response models, operation gating, handshake support, and a minor protocol version bump.

## Target Architecture

```text
Interaction command/tool
  -> typed request preserving target intent
  -> UIAutomationService
  -> verb service
  -> UIInputPolicy
  -> AutomationElementResolver
  -> ActionInputDriver
  -> SyntheticInputDriver
  -> UIInputExecutionResult
  -> debug log + visualizer + caller response
```

### New Policy Model

Add:

```text
Core/PeekabooAutomationKit/Sources/PeekabooAutomationKit/Strategy/UIInputStrategy.swift
Core/PeekabooAutomationKit/Sources/PeekabooAutomationKit/Strategy/UIInputPolicy.swift
```

Suggested core types:

```swift
public enum UIInputStrategy: String, Sendable, Codable {
    case actionFirst
    case synthFirst
    case actionOnly
    case synthOnly
}

public enum UIInputVerb: String, Sendable, Codable {
    case click
    case scroll
    case type
    case hotkey
    case setValue
    case performAction
}

public enum UIInputExecutionPath: String, Sendable, Codable {
    case action
    case synth
}

public struct UIInputPolicy: Sendable, Codable {
    public var defaultStrategy: UIInputStrategy
    public var perVerb: [UIInputVerb: UIInputStrategy]
    public var perApp: [String: AppUIInputPolicy]
}
```

Keep config precedence consistent with the rest of Peekaboo:

```text
CLI flag -> environment -> config file -> built-in default
```

The earlier env-first sketch is useful for emergency override semantics, but it conflicts with current configuration behavior. If a true emergency override is needed, add a separate explicit variable such as `PEEKABOO_INPUT_STRATEGY_FORCE`.

Initial Phase 1 default:

```text
defaultStrategy: synthFirst
click: synthFirst
scroll: synthFirst
type: synthFirst
hotkey: synthFirst
```

Later defaults flip per verb.

Current rollout default after the Phase 3 click/scroll flip:

```text
defaultStrategy: synthFirst
click: actionFirst
scroll: actionFirst
type: synthFirst
hotkey: synthFirst
setValue: actionOnly
performAction: actionOnly
```

### New Result Metadata

Each verb service should produce an internal result:

```swift
public struct UIInputExecutionResult: Sendable {
    public var verb: UIInputVerb
    public var strategy: UIInputStrategy
    public var path: UIInputExecutionPath
    public var fallbackReason: UIInputFallbackReason?
    public var bundleIdentifier: String?
    public var elementRole: String?
    public var actionName: String?
    public var anchorPoint: CGPoint?
    public var duration: TimeInterval
}
```

Public APIs can keep current return values initially. `UIAutomationService` needs access to this metadata for
debug logging and visualizer behavior.

### New Drivers

Add a concrete action driver:

```text
Core/PeekabooAutomationKit/Sources/PeekabooAutomationKit/Services/UI/ActionInputDriver.swift
```

Do not make it a static singleton only. Services need injectable seams for tests.

Suggested protocols:

```swift
protocol ActionInputDriving: Sendable {
    func click(_ element: AutomationElement) async throws -> ActionInputResult
    func rightClick(_ element: AutomationElement) async throws -> ActionInputResult
    func scroll(_ element: AutomationElement, direction: ScrollDirection, pages: Int) async throws -> ActionInputResult
    func setValue(_ element: AutomationElement, value: String) async throws -> ActionInputResult
    func performAction(_ element: AutomationElement, actionName: String) async throws -> ActionInputResult
    func hotkey(application: RunningApplication, keys: [String]) async throws -> ActionInputResult
}

protocol SyntheticInputDriving: Sendable {
    // Thin wrapper over current InputDriver.
}
```

Start with the minimum methods needed by click, scroll, type, and hotkey. Broaden later.

### Element Wrapper and Resolver

Add:

```text
Core/PeekabooAutomationKit/Sources/PeekabooAutomationKit/Services/UI/AutomationElement.swift
Core/PeekabooAutomationKit/Sources/PeekabooAutomationKit/Services/UI/AutomationElementResolver.swift
```

`AutomationElement` wraps AXorcist `Element` and exposes computed properties:

- name with fallback chain: title, label, description, role description
- role
- frame in screen coordinates
- value
- action names
- settable predicate
- parent and children when needed
- enabled, focused, offscreen

`AutomationElementResolver` resolves fresh handles from:

- latest explicit snapshot ID plus element ID
- query plus app/window context
- focused element for type/set-value
- running app context for menu hotkey resolution

Do not store raw AX handles in snapshots across agent turns. Use snapshots as addressing context and refetch.

### Action Error Classification

Add typed action errors:

```swift
public enum ActionInputError: Error, Sendable {
    case unsupported(reason: String)
    case staleElement
    case permissionDenied
    case targetUnavailable
    case failed(reason: String)
}
```

Fallback only on errors that mean "action path cannot cover this":

- unsupported action
- unsupported attribute
- value not settable
- missing element for action-first but coordinates exist
- no menu item matching hotkey

Do not fallback silently on permission denial or target ambiguity. Those should surface.

## Verb Behavior

### Click

Action path:

- Resolve element.
- Try `AXPress` for primary click.
- Try `AXShowMenu` for secondary click when available.
- Treat double-click as unsupported initially unless a target-specific action exists.
- Return visualizer anchor as element frame midpoint.

Synth fallback:

- Current `ClickService` point resolution and `InputDriver.click(at:)`.
- Preserve window-movement diagnostics for coordinate paths.

Required MCP change:

- `ClickTool` must pass element IDs/queries to automation, not pre-resolve to coordinates.

### Scroll

Action path:

- Resolve scroll target.
- Try accessibility scroll actions conservatively.
- Do not move the mouse.
- Return anchor as element midpoint or scroll container midpoint.

Synth fallback:

- Current mouse-positioned wheel event path.

Risk:

- Scroll action names and behavior vary more than press. Expect higher fallback rate.

### Type

Keep two separate semantics:

- `type`: observable typing, may trigger IME/autocomplete/undo grouping.
- `set_value`: direct AX value mutation.

Action path for existing `type(text:target:clearExisting:)` can use direct set-value only when:

- target element resolves
- replacement semantics are requested
- value attribute is settable
- caller did not request per-character typing delay or special key actions

`typeActions` should remain synth-first until a separate planner can prove the action path preserves behavior.

Add new tool:

```text
set_value(element, value)
```

This is the form UX win. It should not be hidden behind synthetic typing.

### Hotkey

Action path:

- Resolve target app.
- Walk menu bar.
- Match key code plus modifier mask against menu item shortcuts.
- Invoke the menu item press action.

Synth fallback:

- Current foreground `InputDriver.hotkey`.
- Current targeted CGEvent-to-PID path where requested.

Known unsupported action cases:

- Esc
- arrow keys during text editing
- F-keys
- custom in-app/global shortcuts not represented in menus
- games/kiosk/full-screen apps

Add per-app overrides:

```json
{
  "input": {
    "perApp": {
      "com.googlecode.iterm2": {
        "hotkey": "synthFirst"
      }
    }
  }
}
```

### Drag, Swipe, Move, Force Click

Stay synthesis-only.

Reasons:

- drag path fidelity needs intermediate motion events
- some apps require mouse-down hold before motion
- force/pressure has no AX equivalent
- canvas and game UIs often need pixel-level input

Future synth improvements belong behind the synthetic driver, not in the policy model:

- stateful modifier tracking
- current-layout key translation
- pre-post event mutation hook
- public virtual HID spike

## Agent and MCP Surface

Target long-term agent-facing minimum:

- `perceive`
- `click`
- `secondary_action`
- `scroll`
- `drag`
- `type_text`
- `press_key`
- `set_value`
- `perform_action`

Keep broad CLI commands for humans. The CLI can expose direct power tools without forcing the agent prompt surface to grow.

### Generic Action Invoker

Add:

```text
perform_action(element, actionName)
```

Validation policy:

- If advertised action names are available, include them in error/help text.
- Do not rely on advertisement as the only gate for common actions.
- For arbitrary user-requested actions, reject clearly impossible names before invocation.
- For known standard actions, try and classify the AX error.

This lets new OS/app actions become usable without adding one tool per action.

### Direct Value Setter

Add:

```text
set_value(element, value)
```

Rules:

- Check whether the value attribute is settable.
- Set atomically.
- Verify by reading back when cheap.
- Return old/new value when safe and non-sensitive.
- Do not use this for password/secure fields unless policy explicitly allows it.

### Snapshot Lifecycle

For agent sessions, move toward forced refresh per turn:

```text
perceive -> act -> stop turn / verify with fresh state
```

This is stricter than the current persistent snapshot model but removes an entire class of stale-element and stale-coordinate bugs.

Short-term implementation:

- Keep explicit snapshot IDs.
- Reject action-first element operations on stale/missing snapshots with a clear error.
- Add prompt guardrails requiring `perceive` before actions.

Long-term implementation:

- Turn-scoped snapshot validity in the MCP/session layer.
- Automatic invalidation after mutating actions.
- Clear error telling the model to call `perceive` again.

## Observability

Do not add a telemetry subsystem for this refactor. Peekaboo is OSS and UI automation data is sensitive; persistent
local metrics would add privacy optics, docs, schema, and command surface without giving maintainers useful aggregate
rollout data unless users manually share files.

Keep observability simple:

- return `UIInputExecutionResult` with verb, strategy, chosen path, fallback reason, bundle ID, element role, action
  name, anchor point, and duration
- log chosen path and fallback reason at debug level
- let targeted tests assert dispatcher behavior directly
- ask users for explicit debug logs or command JSON when diagnosing app-specific fallback behavior

Per-app overrides should come from bug reports, local repros, and targeted fixtures, not background metric collection.

## Visualizer

Current overlays assume a screen point and sometimes current mouse location.

Action mode needs explicit anchors:

- click: element frame midpoint
- right-click/show-menu: element frame midpoint
- scroll: scroll element midpoint or visible container midpoint
- set-value: field frame midpoint, or no animation
- hotkey/menu item: no pointer ring; optional menu/action feedback only

Do not read `NSEvent.mouseLocation` for action-mode scroll feedback. It is unrelated to the target and wrong for background operation.

## Config and CLI

Add config:

```json
{
  "input": {
    "defaultStrategy": "synthFirst",
    "click": "synthFirst",
    "scroll": "synthFirst",
    "type": "synthFirst",
    "hotkey": "synthFirst",
    "perApp": {
      "com.example.App": {
        "click": "actionFirst",
        "scroll": "synthFirst"
      }
    }
  }
}
```

Add environment:

```text
PEEKABOO_INPUT_STRATEGY=actionFirst
PEEKABOO_CLICK_INPUT_STRATEGY=actionFirst
PEEKABOO_SCROLL_INPUT_STRATEGY=actionFirst
PEEKABOO_TYPE_INPUT_STRATEGY=synthFirst
PEEKABOO_HOTKEY_INPUT_STRATEGY=synthFirst
```

Add CLI override:

```text
--input-strategy actionFirst
```

Prefer adding the flag first to interaction commands only. A global flag can follow once Commander wiring is clear.

## Bridge Changes

Add operations:

- `setValue`
- `performAction`

Bridge changes:

- request/response DTOs
- operation enum cases
- server handlers
- client adapters
- enabled/supported operation gating
- protocol minor version bump
- version mismatch error that tells the model/user to relaunch the host app

Do not require the CLI process itself to hold Accessibility or Screen Recording. Keep the bridge host as the permissioned service boundary.

## Permissions and Security

Action-first can reduce reliance on synthetic input, but it does not make automation harmless.

Still required:

- Accessibility
- Screen Recording

Still useful as user-facing distinction:

- action-first modes can avoid routine synthetic input
- cursor no longer warps for supported verbs
- background operation becomes possible for supported verbs
- fewer reasons to need Input Monitoring-like affordances

Add per-bundle approval later, especially for agent mode:

- allow once
- allow always
- deny
- persistent approved bundle IDs
- session approved bundle IDs
- approval audit logs

Security warning text:

> Allowing this assistant to use this app introduces new risks, including those related to prompt injection attacks, such as data theft or loss. Carefully monitor the assistant while it uses this app.

## Tests

### Unit Tests

Policy:

- config/env/CLI precedence
- per-verb override
- per-app override
- invalid strategy values

Dispatcher:

- `actionFirst` action success does not call synth
- `actionFirst` unsupported falls back to synth
- `actionFirst` permission denied does not fallback silently
- `actionOnly` unsupported throws
- `synthFirst` preserves current behavior
- `synthOnly` never calls action driver

Error classification:

- action unsupported
- attribute unsupported
- invalid/stale element
- permission denied
- target unavailable

MCP:

- `ClickTool` preserves element ID target
- `TypeTool` does not synth-focus when calling `set_value`
- `perform_action` validates request shape
- stale snapshot asks for perceive/fresh snapshot

Bridge:

- handshake advertises new operations
- old host returns actionable version-mismatch error
- disabled operation returns policy error

### GUI / Automation Tests

Guard behind existing automation test controls.

Cover:

- AXPress on a native button
- fallback on unsupported action
- direct value set on text field
- menu-item hotkey invocation
- scroll fallback path
- visualizer anchor for action click

Do not block Phase 0 on GUI tests. Do block default flips on enough guarded real-app coverage.

## Rollout

### Phase 0: Instrumentation

No behavior change.

Land:

- strategy model
- policy resolver
- execution metadata
- debug logs
- counters/timing
- injectable driver seams where needed

Goal:

- learn current per-app/per-verb fallback risk before changing behavior.

### Phase 1: Implement Default-Off Action Paths

Default remains `synthFirst`.

Land:

- `ActionInputDriver`
- `AutomationElement`
- `AutomationElementResolver`
- `AutomationElementRepresenting` mock seam for in-memory action-driver tests
- service dispatchers
- tests for click/scroll/type/hotkey dispatch
- visualizer metadata plumbing

Do not flip defaults yet.

### Phase 2: Fix MCP Intent Preservation

Land before action defaults:

- `ClickTool` passes element/query intent through
- `TypeTool` separates focus/type from direct value set
- action result metadata reaches MCP responses where useful
- prompt guardrails prefer element targets and fresh perceive

### Phase 3: Flip Click and Scroll

Set:

```text
click: actionFirst
scroll: actionFirst
```

Watch:

- fallback rate per app
- failed action rate
- stale snapshot errors
- visualizer mismatch reports

If an app stays above an agreed fallback threshold, keep it in `synthFirst` via per-app policy.

### Phase 4: Add Missing Tools

Expose:

- `set_value`
- `perform_action`

Add bridge support and MCP schemas. Keep direct CLI equivalents or subcommands for power users.

### Phase 5: Flip Type and Hotkey Selectively

Deferred selective rollout, not required for the initial action-first refactor completion. Set broader defaults only when
app-specific evidence supports it.

Likely shape:

- `set_value` defaults action-first.
- existing `typeActions` remains synth-first.
- hotkey defaults action-first only for menu-bound chords with fallback.

Maintain per-app overrides.

### Phase 6: Hardening and Optional Synth Backend Improvements

After action-first is stable:

- proper keyboard layout translation
- stateful modifier tracker
- drag interpolation policy
- force-click options
- virtual HID spike
- pre-post event mutation hook
- per-bundle approval flow
- lazy/faulting AX tree work if perception cost becomes the bottleneck
- centralized AX observer/runloop architecture if action resolution needs notification waits

## Risks

1. Action-name advertising is unreliable.
   Try common actions; catch unsupported errors; fall back. Do not poison fallback because an element lied.

2. Action invocation is synchronous only for delivery.
   It does not mean UI settled. Tests and tools need notification waits or settle polling.

3. Snapshot freshness becomes load-bearing.
   Action paths require fresh element resolution. Do not flip defaults until stale snapshot behavior is explicit.

4. MCP coordinate lowering blocks action-first.
   Fix ClickTool and TypeTool before default flips.

5. Hotkey parity is impossible with actions alone.
   Menu resolution misses Esc, arrows, F-keys, custom global shortcuts, and many terminal/editor cases.

6. Scroll action support varies.
   Expect conservative fallback.

7. Visualizer semantics change.
   No cursor moved in action mode. Draw at element anchor or suppress pointer animation.

8. Per-app behavior is unknowable upfront.
   Bug reports and targeted repros decide app overrides. Some apps may stay `synthFirst` forever.

## First PR

Keep the first PR deliberately boring:

- add `UIInputStrategy`
- add `UIInputPolicy`
- add config/env/CLI resolution tests
- add execution metadata types
- add debug path logging
- add driver protocols/fakes
- wire services with default `synthFirst`
- prove no behavior change

Do not include action invocation behavior in the first PR unless the diff stays small.

## Non-Goals

- deleting `InputDriver`
- making drag/swipe action-based
- solving secure-input password entry through private APIs
- storing raw AX handles across turns
- replacing the broad CLI surface with a minimal agent surface
- adopting private framework constants or private assistive-tool APIs

## Success Criteria

Short term:

- current tests pass under `synthFirst` / `synthOnly`
- execution results and debug logs report chosen path and fallback reason
- MCP preserves element intent for click/scroll

Medium term:

- click and scroll can run action-first without cursor warp in common native apps
- app-specific fallback behavior is diagnosable from explicit repro logs
- stale-coordinate click class is reduced for element-targeted actions

Long term:

- routine forms use `set_value`
- menu-bound hotkeys can run in background
- synthetic input remains available for the verbs and apps that truly need it
- users have a supported `synthOnly` escape hatch
