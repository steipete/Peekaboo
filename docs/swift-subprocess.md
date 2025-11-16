---
summary: 'Review swift-subprocess Adoption Guide guidance'
read_when:
  - 'planning work related to swift-subprocess adoption guide'
  - 'debugging or extending features described here'
---

# swift-subprocess Adoption Guide

## Why We Care
- Our test suites launch dozens of child processes (`swift run peekaboo`, `axorc`, shell utilities) and each file hand-rolls `Process`, `Pipe`, and blocking drain logic. This duplication is fragile and contributes to flakiness when stdout/stderr buffers fill.
- The [`swift-subprocess`](https://github.com/swiftlang/swift-subprocess) package (latest tag `0.2.1`, Swift 6.1+/macOS 13+) ships an async/await-native wrapper around `posix_spawn`, providing streaming output via `AsyncSequence`, structured configuration, and built-in cancellation. It eliminates the classic deadlock that occurs when `Process` pipes aren’t drained quickly enough.citeturn1open0turn1open1turn1open2
- Package status: beta, owned by the Swift project, with the first stable release targeted for early 2026. Expect API polishing; keep adoption behind our own façade so we can react to breaking changes quickly.citeturn1open0turn1open1

## Pilot Scope (Tests First)
- Focus the first integration on the now-retired CLI runner (`Apps/CLI/Tests/CLIAutomationTests/Support/CommandRunner.swift`). All “safe” suites run via `InProcessCommandRunner`, and historical references to `PeekabooCLITestRunner` have been removed.
- Audit additional hot spots once the pilot lands:
  - `AXorcist` test helpers (`AXorcist/Tests/AXorcistTests/CommonTestHelpers.swift`) when invoking the `axorc` binary.
  - CLI automation tests that manually stand up `Process` instances for menu/window focus helpers (`Apps/CLI/Tests/CLIAutomationTests/*.swift`, see `rg "Pipe()"` output). These can eventually share a common helper that wraps Subprocess.
- Production code paths (e.g. `ShellTool`, `DockService`) remain untouched until the test pilot proves stable and we design a broader façade for long-lived services.

## Integration Plan
1. **Add the dependency**  
  - Declare `swift-subprocess` in the relevant package manifests: start with `Apps/CLI/Package.swift` and `AXorcist/Package.swift` test targets only. Keep it test-only until we validate behavior.
   - Pin to an explicit minor version (`from: "0.2.1"`) and enable exact revisions in `Package.resolved` to avoid silent API shifts.
2. **Wrap Subprocess behind a helper**  
   - Introduce a small internal type (e.g. `TestChildProcess`) that mirrors the subset of features we rely on (arguments, environment, streaming stdout/stderr, timeout). This wrapper will call into Subprocess’ `ChildProcess.spawn(...)`, surface async iteration of `process.stdout.lines`, and return collected output on success/failure.
   - Preserve our existing error surface (`CommandError(status:output:)`) by translating `SubprocessError` into our domain model. Include the captured stderr text in thrown errors.
3. **Retire `PeekabooCLITestRunner`**  
   - Historical note: the runner has been removed now that every automation suite runs via the harness.
4. **Roll out to other helpers**  
   - Migrate AXorcist’s `runAXORCCommand` and similar utilities once the CLI pilot is stable for a week of CI runs.
   - Document any platform-specific observations (e.g. sandbox quirks, resource cleanup) in this file as we go.
5. **Evaluate production adoption**  
   - After tests prove reliable, design a PeekabooCore abstraction (`ChildProcessService`) that can swap `Process` vs. Subprocess internally. Production code often needs cancellation, long-running streaming, and the occasional pseudo-terminal; confirm Subprocess’ PTY story before we rely on it inside the MCP transports.

## Usage Cheatsheet
```swift
import Subprocess

struct TestChildProcess {
    static func runPeekaboo(_ args: [String]) async throws -> String {
        var options = ChildProcessOptions()
        options.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        options.environment = ProcessInfo.processInfo.environment

        let process = try await ChildProcess.spawn(
            command: "/usr/bin/env",
            arguments: ["swift", "run", "peekaboo"] + args,
            options: options
        )

        var output = ""
        for try await line in process.stdout.lines {
            output.append(line)
            output.append("\n")
        }

        let exitStatus = await process.waitForExit()
        guard exitStatus == .code(0) else {
            throw CommandError(status: exitStatus.exitCode, output: output)
        }
        return output
    }
}
```
- `ChildProcess.spawn` returns immediately; consumers iterate its `AsyncThrowingStream` properties (`stdout.bytes`, `stdout.lines`, `stderr.lines`) without extra pipes or threads.
- `waitForExit()` yields a `ChildProcess.Termination` enum. Use `.code(Int32)` for numeric exit codes, `.signal(Int32)` for signal terminations.
- Cancellation: wrapping the spawn in `withTimeout` or explicitly calling `process.terminate()` cooperates with async tasks. This will help us enforce per-test timeouts instead of blocking on `waitUntilExit()`.

## Open Questions
- PTY support is currently experimental. Even though our MCP client now sticks to pipes, confirm Subprocess’ pseudo-terminal roadmap before depending on it for future CLI integrations.
- Some of our tests rely on combined stdout/stderr ordering. Subprocess exposes them separately; we need to decide whether to merge streams manually or only capture stderr when non-empty.
- Monitor the upstream issue tracker for breaking changes ahead of `1.0.0`; update this doc with any migration notes after each dependency bump.
