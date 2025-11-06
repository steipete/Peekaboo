# Test Refactor Task List

The read-only automation suites are steadily moving away from `swift run` subprocesses
and into the new in-process harness (`Support/InProcessCommandRunner.swift` plus
`Support/TestServices.swift`). Drag, space, app, window CLI, dock, menu, and dialog
read suites now run hermetically. The remaining work below will finish the migration
so the entire “safe” matrix can execute without touching live macOS services.

## 1. Complete the Command Harness Rollout
- **ScrollCommandTests.swift**, **SwipeCommandTests.swift**, **MoveCommandTests.swift**, **PressCommandTests.swift**  
  These suites still call into the live automation service. Create fixture contexts
  (similar to `DragCommandTests`) and route the help/validation cases through
  `InProcessCommandRunner`. Stub out automation calls in `TestServicesFactory` as needed.
- **AnalyzeCommandTests.swift**, **RunCommandTests.swift**, **ListCommandTests** (CLI variants)  
  Audit each suite for parsing-only tests that still shell out. If no real UI work is
  required, wire them to the harness with appropriate test data.
- **PeekabooCLITestRunner.swift**  
  Once no read suite references this helper, delete the file and clean any imports.

## 2. Extend/Adjust Test Stubs
- Flesh out automation stubs so commands that issue `click`, `type`, `scroll`, etc.
  can be called safely. At a minimum, record the request and return success so the
  CLI logic continues past validation.
- Add helper builders in `TestServicesFactory` for frequently used scenarios
  (e.g., common application/window fixtures) to keep future tests concise.

## 3. Documentation & Guardrails
- Update `swift-subprocess.md` and any onboarding docs once the harness covers all
  read suites so new contributors know to use the in-process approach by default.
- Consider adding a lightweight lint (or test) that fails if new tests import
  `PeekabooCLITestRunner`, keeping the suite hermetic.

## 4. Verification
- After each conversion, re-run the safe matrix (`pnpm run test:safe`) and the read
  automation pass (`PEEKABOO_INCLUDE_AUTOMATION_TESTS=true RUN_AUTOMATION_READ=true swift test`)
  via tmux to ensure no regressions.
