# Test Refactor Task List

The read-only automation suites are steadily moving away from `swift run` subprocesses
and into the new in-process harness (`Support/InProcessCommandRunner.swift` plus
`Support/TestServices.swift`). Drag, space, app, window CLI, dock, menu, and dialog
read suites now run hermetically. The remaining work below will finish the migration
so the entire “safe” matrix can execute without touching live macOS services.

## 1. Complete the Command Harness Rollout
- ✅ **ScrollCommandTests.swift**, **SwipeCommandTests.swift**, **MoveCommandTests.swift**, **PressCommandTests.swift**, **AppCommandTests.swift**, **DragCommandTests.swift**  
  All four suites now run via `InProcessCommandRunner` with Fixture-driven `TestServicesFactory` contexts.
- ✅ **RunCommandTests.swift**, ✅ **ListCommandTests** (CLI variants)  
  Command coverage moved to the harness by wiring `StubProcessService`, `StubScreenCaptureService`, and in-memory application/window fixtures.
- ~~**AnalyzeCommandTests.swift**~~  
  Removed (no standalone `analyze` CLI command exists—`image --analyze` already has coverage inside `ImageCommandTests`). Reintroduce only if a dedicated `AnalyzeCommand` is added to the CLI.

## 2. Extend/Adjust Test Stubs
- ✅ Automation stubs now record calls/results for `scroll`, `swipe`, `press`, `moveMouse`, wait-for-element, etc., enabling hermetic CLI coverage.
- ✅ Added `TestServicesFactory.AutomationTestContext`, injectable `StubProcessService`, and configurable `StubScreenCaptureService` to keep new harness suites concise.
- TODO: continue identifying repetitive fixture construction in remaining suites and upstream them into `TestServicesFactory`.

## 3. Documentation & Guardrails
- Update `swift-subprocess.md` and any onboarding docs once the harness covers all
  read suites so new contributors know to use the in-process approach by default.
- Consider adding a lightweight lint (or test) that fails if anyone reintroduces
  `PeekabooCLITestRunner`, keeping the suite hermetic.

## 4. Verification
- After each conversion, re-run the safe matrix (`pnpm run test:safe`) and the read
  automation pass (`PEEKABOO_INCLUDE_AUTOMATION_TESTS=true RUN_AUTOMATION_READ=true swift test`)
  via tmux to ensure no regressions.
