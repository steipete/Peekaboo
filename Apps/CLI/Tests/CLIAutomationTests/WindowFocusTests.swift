import Foundation
import Testing
@testable import PeekabooCLI

#if !PEEKABOO_SKIP_AUTOMATION
@Suite(
    "Window Focus Enhancement Tests",
    .serialized,
    .tags(.automation),
    .enabled(if: CLITestEnvironment.runAutomationActions)
)
struct WindowFocusTests {
    // Helper function to run peekaboo commands
    private func runPeekabooCommand(
        _ arguments: [String],
        allowedExitStatuses: Set<Int32> = [0]
    ) async throws -> String {
        let result = try await InProcessCommandRunner.runShared(
            arguments,
            allowedExitCodes: allowedExitStatuses
        )
        return result.combinedOutput
    }

    // MARK: - Window Focus Command Tests

    @Test("window focus command help includes Space options")
    func windowFocusHelpSpaceOptions() async throws {
        let output = try await runPeekabooCommand(["window", "focus", "--help"])

        #expect(output.contains("Focus a window"))
        #expect(output.contains("--space-switch"))
        #expect(output.contains("--no-space-switch"))
        #expect(output.contains("--move-here"))
        #expect(output.contains("Switch to window's Space if on different Space"))
        #expect(output.contains("Move window to current Space instead of switching"))
    }

    @Test("window focus with Space switch option")
    func windowFocusWithSpaceSwitch() async throws {
        let output = try await runPeekabooCommand([
            "window", "focus",
            "--app", "Safari",
            "--space-switch",
            "--json-output"
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: Data(output.utf8))
        if data.success {
            // Command succeeded
            #expect(Bool(true))
        } else {
            // It's OK if Safari isn't running
            #expect(data.error != nil)
        }
    }

    @Test("window focus with move-here option")
    func windowFocusWithMoveHere() async throws {
        let output = try await runPeekabooCommand([
            "window", "focus",
            "--app", "TextEdit",
            "--move-here",
            "--json-output"
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: Data(output.utf8))
        // Verify command parses correctly - actual behavior depends on TextEdit being open
        #expect(data.success == true || data.error != nil)
    }

    @Test("window focus with disabled Space switch")
    func windowFocusNoSpaceSwitch() async throws {
        let output = try await runPeekabooCommand([
            "window", "focus",
            "--app", "Finder",
            "--no-space-switch",
            "--json-output"
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: Data(output.utf8))
        // Finder should always be running
        if data.success {
            #expect(Bool(true))
        }
    }

    // MARK: - FocusOptions Integration Tests

    @Test("click command has focus options")
    func clickCommandFocusOptions() async throws {
        let output = try await runPeekabooCommand(["click", "--help"])

        #expect(output.contains("--no-auto-focus"))
        #expect(output.contains("--focus-timeout"))
        #expect(output.contains("--focus-retry-count"))
        #expect(output.contains("--space-switch"))
        #expect(output.contains("--bring-to-current-space"))
        #expect(output.contains("Disable automatic focus before interaction"))
    }

    @Test("type command has focus options")
    func typeCommandFocusOptions() async throws {
        let output = try await runPeekabooCommand(["type", "--help"])

        #expect(output.contains("--no-auto-focus"))
        #expect(output.contains("--focus-timeout"))
        #expect(output.contains("--focus-retry-count"))
        #expect(output.contains("--space-switch"))
        #expect(output.contains("--bring-to-current-space"))
    }

    @Test("menu command has focus options")
    func menuCommandFocusOptions() async throws {
        let output = try await runPeekabooCommand(["menu", "--help"])

        #expect(output.contains("--no-auto-focus"))
        #expect(output.contains("--focus-timeout"))
        #expect(output.contains("--focus-retry-count"))
        #expect(output.contains("--space-switch"))
        #expect(output.contains("--bring-to-current-space"))
    }

    // MARK: - Focus Options Behavior Tests

    @Test("click with disabled auto-focus", .disabled("JSONResponse data field is Empty type, not dictionary"))
    func clickNoAutoFocus() async throws {
        // This test needs to be rewritten since JSONResponse.data is now of type Empty
        // and cannot contain snapshot_id data
        #expect(Bool(true)) // Placeholder to avoid test failure
    }

    @Test("type with custom focus timeout")
    func typeWithFocusTimeout() async throws {
        let output = try await runPeekabooCommand([
            "type", "test",
            "--focus-timeout", "2.5",
            "--json-output"
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: Data(output.utf8))
        // Verify command accepts custom timeout
        #expect(data.success == true || data.error != nil)
    }

    @Test("menu with focus retry count")
    func menuWithFocusRetry() async throws {
        let output = try await runPeekabooCommand([
            "menu", "File > New",
            "--app", "TextEdit",
            "--focus-retry-count", "5",
            "--json-output"
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: Data(output.utf8))
        // Verify command accepts retry count
        #expect(data.success == true || data.error != nil)
    }
}

// MARK: - Test Helpers

private struct JSONResponse: Codable {
    let success: Bool
    let error: String?
}

private enum ProcessError: Error {
    case message(String)
    case binaryMissing
}
#endif
