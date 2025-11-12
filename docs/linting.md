---
summary: 'Record the current lint situation and outline the refactor plan.'
read_when:
  - 'tackling lint regressions or prepping a refactor that crosses many files'
  - 'planning doc changes that need editor or playground upkeep'
---

# Linting & Formatting Roadmap

## Current status (November 12, 2025)

- SwiftLint run from the repo root (`swiftlint --config .swiftlint.yml`) emits ~760 warnings/errors spread across 616 Swift files. The biggest concentrations are huge CLI test suites (type_body_length/file_length), SwiftUI playground views (line_length/cyclomatic_complexity/multiple closures with trailing closures), and some helper/test utilities with force-casts/force-tries.
- Commander now obeys the lint rules—our new DocC work introduced no fresh violations. The remaining noise is entirely inside CLI + Playground targets that pre-date this change.
- Automating the fix must be surgical; the current solution will focus on the playground views first because the warning density there is lower and the necessary changes are localized (remove trailing-closure syntax, shorten long lines, drop stale suppressions).

## Short-term tasks (today)

1. **Document the refactor plan** (this file) so other agents/engineers know where to land the long-standing issues.
2. **Refactor Playground views** to use explicit `label:`/`action:` closures instead of only trailing closures and remove unused `swiftlint:disable` pragmas in `LogViewerWindow`.
3. **Shorten blatantly long view methods** (e.g., chunk `PlaygroundApp` / `ControlsView` if possible) and prepare follow-up issues for the CLI tests that exceed `function_body_length` or `file_length` thresholds.

## Mid/long-term plan (next wave)

- Break `CommanderBinderTests` and similarly oversized suites into smaller files/suites so they fall below `type_body_length`/`file_length` limits while keeping loops of helper functions grouped logically.
- Triage the remaining `function_body_length`/`cyclomatic_complexity` warnings in `PlaygroundApp` by extracting helpers and adopting `#warning` stubs for large but stable blocks; consider permalinks for complexity-critical sections.
- Work through the `force_cast`/`force_try` hotspots in test helpers by wrapping them in safe wrappers or using `XCTUnwrap` style assertions (preferring `fatalError` only when truly unreachable).
- Re-run SwiftLint with `--reporter json` after each batch and capture the residual warnings in a follow-up section of this doc.

## Communication

- Mention the lint count when you reopen CI runs; post-cleanup, future docs should reference this file to track progress.
- If any rule needs temporary relaxation, add it to `.swiftlint.yml` with a clear justification and document it here (use `read_when` to capture when to revisit).

## Activity log

- `2025-11-12`: Documented the lint roadmap, refactored the Playground views (`ContentView`, `LogViewerWindow`, `TextInputView`) to stop using trailing-closure syntax when multiple blocks are supplied, and removed stale `swiftlint:disable` comments so those files pass linting.
- `2025-11-12`: Swapped the expand buttons in `AgentActivityView`, `ElementDetailsView`, and `AllElementsView` to explicit `label:` closures so the `multiple_closures_with_trailing_closure` warnings are gone for those helpers.
- `2025-11-12`: Reworked the voice/text input buttons in `StatusBarInputView`, including the voice toggle, submit, realtime recording controls, StatusBar action buttons, metadata/expand controls, and the session sidebar header/search buttons so every StatusBar/control component now supplies `label:` closures and obeys the trailing-closure rule.
- `2025-11-12`: Patched the Session Chat input areas so every button (cancel, submit, mode swap, recording) now uses explicit `label:` closures, further reducing the trailing-closure violations in the message UI.
- `2025-11-12`: Updated the detailed message row to use explicit `label:` closures for the Retry/expand controls, ensuring the rich message UI also stays clean.
- `2025-11-12`: Converted the App Selector's per-application buttons inside the detail menu to the `label:` form, knocking another source of trailing-closure warnings in the UI component library.
- `2025-11-12`: Converted the Main Window session popover close button to the explicit `label:` form so even the session list controls comply with the trailing-closure rule.
- `2025-11-12`: Made the Enhanced Session Detail configuration button explicit so its action no longer relies on trailing-closure syntax.
- `2025-11-12`: Updated the Visualizer test automation buttons so their async animation triggers now supply explicit `label:` closures, keeping the visualization helpers lint-clean.
- `2025-11-12`: Adjusted the Image Inspector zoom controls so their buttons now supply `label:` closures, keeping the accessory view lint-clean.
- `2025-11-12`: Replaced the forced `SpeechError` cast in `MainWindow` with optional binding so the error-handling path no longer hits the `force_cast` rule.
- `2025-11-12`: Converted the Main Window session popover close button to the explicit `label:` form so even the session list controls comply with the trailing-closure rule.
- `2025-11-12`: Converted the Enhanced Session Detail tabs to explicit `label:` closures so the top-level controls no longer trip the trailing-closure rule.
- `2025-11-12`: Patched the Session Chat toolbar and expanded tool call components so their toolbar disclosure and image buttons now use `label:` closures, keeping the message and tool-call UIs tidy.
- `2025-11-12`: Patched the status bar unified feed expand buttons, ensuring the collapsible message controls obey the trailing-closure rule as well.
- `2025-11-12`: Replaced the trailing closure call to `NSAnimationContext.runAnimationGroup` with its `completionHandler:` parameter to remove the last `multiple_closures_with_trailing_closure` hit in the animation overlay manager.
- `2025-11-12`: Refactored `PlaygroundApp` so click/key logging now uses helper functions and dictionary lookups, eliminating the long line/cyclomatic-complexity warnings while keeping the event logging logic intact.
- `2025-11-12`: Shortened a long JSON fixture in `SessionTests` by moving the literal into a multi-line string so the line stays under 120 characters and the line-length rule is satisfied.
- `2025-11-12`: Converted the Tool Execution History expand control to the `label:` form so the history list complies with the trailing-closure rule.
- `2025-11-12`: Updated the detailed message row to use explicit `label:` closures for the Retry/expand controls, ensuring the rich message UI also stays clean.
- `2025-11-12`: Converted the App Selector's per-application buttons inside the detail menu to the `label:` form, knocking another source of trailing-closure warnings in the UI component library.
- `2025-11-12`: Adjusted the Realtime session UI so the toolbar buttons use explicit `label:` closures (gear, keyboard, recording, etc.) and the expand/detail image buttons now follow the same pattern, erasing the final trailing-closure hits from that view.
- `2025-11-12`: Updated the status bar menu and expanded tool call components so their disclosure and image buttons also use `label:` closures and no longer trip the trailing-closure rule.
- `2025-11-12`: Converted the expanded tool call buttons to the `label:` form so tool inspection also plays nicely with the trailing-closure rule.
- `2025-11-12`: Updated the detailed message row to use explicit `label:` closures for the Retry/expand controls, ensuring the rich message UI also stays clean.
- `2025-11-12`: Patched `RealtimeConversationView` so every button supplying both `action` and a closure now uses the `label:` form, clearing the remaining trailing-closure warnings in the Tachikoma realtime UI.
- `2025-11-12`: Converted the session/delete/open buttons in `SessionComponents` so they also provide `label:` closures, brushing another small corner of the trailing-closure backlog.
- `2025-11-12`: Reworded the `SessionStore` documentation comment into multiple lines so it now satisfies the line-length rule without losing detail.
- `2025-11-12`: Simplified `PlaygroundApp`'s global click monitor by extracting descriptor helpers and early-returning when there is no window hit so the closure now stays below the cyclomatic-complexity limit.
- `2025-11-12`: Broke the drag completion details in `DragDropView` into structured pieces so the logging line is shorter and the `line_length` warning disappears.
- `2025-11-12`: Shortened the `currentCommit` extraction in `BuildStalenessChecker` and rewrote the modified-file loop with a `for ... where` clause so both the `line_length` and `for_where` warnings are resolved.
- `2025-11-12`: Split the config file/credentials print strings and broke the provider hint into two lines so `ConfigCommand` now obeys the `line_length` budget for those sections.
- `2025-11-12`: Reworked `AgentOutputDelegate`'s success/error logging helpers so each status line is composed of small segments, eliminating the `line_length` hits while keeping the verbose/helpful output and preserving the newly introduced helper APIs.
- `2025-11-12`: Shortened the `ListCommand` menu-bar frame print by precomputing the origin/size strings so the line now stays within 120 characters.
- `2025-11-12`: Extracted a helper to print each menu-bar item so `ListCommand.printMenuBarItems` now fits within the `function_body_length` limit.
- `2025-11-12`: Split `ScreensSubcommand.run` by delegating construction of list data, summary, metadata, and plain-text output to helpers so the core run method now complies with `function_body_length` while keeping the same response.
- `2025-11-12`: Refactored `AgentOutputDelegate.handleToolCallStarted` into a dedicated printer helper (and moved the entire delegate implementation into a private extension) so the type body shrank below 400 lines while keeping the same terminal output and flow for communication tools.
- `2025-11-12`: Simplified `SeeCommand` logging/output strings by building the verbose detail line from short segments and by adding a reusable screen-display helper so the CLI output lines now obey the `line_length` rule.
- `2025-11-12`: Shortened every overlong `AgentCommand` prompt/notification (header banner, error/resume hints, terminal capabilities debug, session lists) and added a `printCapabilityFlag` helper so the file now satisfies `line_length` without changing the colored CLI experience.
- `2025-11-12`: Refactored `AgentCommand.runInternal` into helper-driven stages (logging/MCP setup, resume handling, task construction), consolidated the session list printer into smaller helpers, and encapsulated the audio workflow so the helper functions share consistent logging and the primary method stays within the body/complexity limits.
- `2025-11-12`: Split the AXObserverCenter logging strings into joined segments via `logSegments`/`describePid` so each message stays under 120 characters yet retains the caller, PID, and notification context.
- `2025-11-12`: Slimmed `AXORCMain` usage/help strings and observe-run logging by building them from smaller pieces, keeping the CLI hints readable while satisfying `line_length`.
- `2025-11-12`: Shortened the Playground controls date-change log string, removed unused `swiftlint:disable` pragmas in `ImageCaptureLogicTests`, updated the Menu helper closures to `-> Void`, and refactored `SeeCommandAnnotationTests.enhancedDetectionWindowContext` into helper-driven helpers so the function now fits the `function_body_length` budget.
- `2025-11-12`: Pulled the Playground click monitor logic into `handleGlobalMouseClick`, broke the screen-coordinate math into separate variables, and simplified the logger setup so the `line_length` and `cyclomatic_complexity` warnings in `PlaygroundApp.swift` no longer occur.
