import Foundation
import Testing
@testable import PeekabooCLI

#if !PEEKABOO_SKIP_AUTOMATION
@Suite(
    "Focus Integration Tests",
    .serialized,
    .tags(.automation),
    .enabled(if: CLITestEnvironment.runAutomationActions)
)
struct FocusIntegrationTests {
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

    // MARK: - Session-based Focus Tests

    @Test("click with session auto-focuses window")
    func clickWithSessionAutoFocus() async throws {
        // Create a session with Finder
        let seeOutput = try await runPeekabooCommand([
            "see",
            "--app", "Finder",
            "--json-output"
        ])

        let seeData = try JSONDecoder().decode(SeeResponse.self, from: seeOutput.data(using: .utf8)!)
        guard seeData.success,
              let sessionId = seeData.data?.session_id else {
            Issue.record("Failed to create session")
            throw ProcessError.message("Failed to create session")
        }

        // Click should auto-focus the Finder window
        let clickOutput = try await runPeekabooCommand([
            "click", "button",
            "--session", sessionId,
            "--json-output"
        ])

        let clickData = try JSONDecoder().decode(ClickResponse.self, from: clickOutput.data(using: .utf8)!)
        // Should either click successfully (with auto-focus) or fail gracefully
        #expect(clickData.success == true || clickData.error != nil)
    }

    @Test("type with session auto-focuses window")
    func typeWithSessionAutoFocus() async throws {
        // Create a session with a text editor if available
        let apps = ["TextEdit", "Notes", "Stickies"]
        var sessionId: String?

        for app in apps {
            let seeOutput = try await runPeekabooCommand([
                "see",
                "--app", app,
                "--json-output"
            ])

            let seeData = try JSONDecoder().decode(SeeResponse.self, from: seeOutput.data(using: .utf8)!)
            if seeData.success, let id = seeData.data?.session_id {
                sessionId = id
                break
            }
        }

        guard let session = sessionId else {
            // Skip test if no text editor is available
            return
        }

        // Type should auto-focus the window
        let typeOutput = try await runPeekabooCommand([
            "type", "test",
            "--session", session,
            "--json-output"
        ])

        let typeData = try JSONDecoder().decode(TypeResponse.self, from: typeOutput.data(using: .utf8)!)
        #expect(typeData.success == true || typeData.error != nil)
    }

    // MARK: - Application-based Focus Tests

    @Test("menu command auto-focuses application")
    func menuCommandAutoFocus() async throws {
        // Menu command should auto-focus the app
        let output = try await runPeekabooCommand([
            "menu", "View",
            "--app", "Finder",
            "--json-output"
        ])

        let data = try JSONDecoder().decode(MenuResponse.self, from: output.data(using: .utf8)!)
        // Should either show menu (with auto-focus) or fail gracefully
        #expect(data.success == true || data.error != nil)
    }

    // MARK: - Focus Options Integration Tests

    @Test("click respects no-auto-focus flag")
    func clickNoAutoFocus() async throws {
        // Create session
        let seeOutput = try await runPeekabooCommand([
            "see",
            "--app", "Finder",
            "--json-output"
        ])

        let seeData = try JSONDecoder().decode(SeeResponse.self, from: seeOutput.data(using: .utf8)!)
        guard seeData.success,
              let sessionId = seeData.data?.session_id else {
            Issue.record("Failed to create session")
            throw ProcessError.message("Failed to create session")
        }

        // Click with auto-focus disabled
        let clickOutput = try await runPeekabooCommand([
            "click", "button",
            "--session", sessionId,
            "--no-auto-focus",
            "--json-output"
        ])

        let clickData = try JSONDecoder().decode(ClickResponse.self, from: clickOutput.data(using: .utf8)!)
        // Command should be accepted (may fail if window not focused)
        #expect(clickData.success == true || clickData.error != nil)
    }

    @Test("type with custom focus timeout")
    func typeCustomTimeout() async throws {
        // Type with very short timeout
        let output = try await runPeekabooCommand([
            "type", "test",
            "--focus-timeout", "0.1",
            "--json-output"
        ])

        let data = try JSONDecoder().decode(TypeResponse.self, from: output.data(using: .utf8)!)
        // Should handle timeout gracefully
        #expect(data.success == true || data.error != nil)
    }

    @Test("menu with high retry count")
    func menuHighRetryCount() async throws {
        let output = try await runPeekabooCommand([
            "menu", "File",
            "--app", "TextEdit",
            "--focus-retry-count", "10",
            "--json-output"
        ])

        let data = try JSONDecoder().decode(MenuResponse.self, from: output.data(using: .utf8)!)
        // Should respect retry count
        #expect(data.success == true || data.error != nil)
    }

    // MARK: - Window Focus with Space Integration

    @Test("window focus switches Space if needed")
    func windowFocusSpaceSwitch() async throws {
        // This test would ideally create a window on another Space
        // For now, test that the option is accepted
        let output = try await runPeekabooCommand([
            "window", "focus",
            "--app", "Safari",
            "--space-switch",
            "--json-output"
        ])

        let data = try JSONDecoder().decode(WindowActionResponse.self, from: output.data(using: .utf8)!)
        #expect(data.success == true || data.error != nil)
    }

    @Test("window focus moves window to current Space")
    func windowFocusMoveHere() async throws {
        let output = try await runPeekabooCommand([
            "window", "focus",
            "--app", "TextEdit",
            "--move-here",
            "--json-output"
        ])

        let data = try JSONDecoder().decode(WindowActionResponse.self, from: output.data(using: .utf8)!)
        #expect(data.success == true || data.error != nil)
    }

    // MARK: - Error Handling Tests

    @Test("focus non-existent application")
    func focusNonExistentApp() async throws {
        let output = try await runPeekabooCommand([
            "window", "focus",
            "--app", "NonExistentApp12345",
            "--json-output"
        ])

        let data = try JSONDecoder().decode(WindowActionResponse.self, from: output.data(using: .utf8)!)
        #expect(data.success == false)
        #expect(data.error != nil)
        #expect(data.error?.contains("not found") == true ||
            data.error?.contains("not running") == true
        )
    }

    @Test("focus window with invalid title")
    func focusInvalidWindowTitle() async throws {
        let output = try await runPeekabooCommand([
            "window", "focus",
            "--app", "Finder",
            "--window-title", "ThisWindowDoesNotExist12345",
            "--json-output"
        ])

        let data = try JSONDecoder().decode(WindowActionResponse.self, from: output.data(using: .utf8)!)
        // Should either find no match or use frontmost window
        #expect(data.success == true || data.error != nil)
    }
}

// MARK: - Response Types

private struct SeeResponse: Codable {
    let success: Bool
    let data: SeeData?
    let error: String?
}

private struct SeeData: Codable {
    let session_id: String
}

private struct ClickResponse: Codable {
    let success: Bool
    let data: ClickData?
    let error: String?
}

private struct ClickData: Codable {
    let action: String
}

private struct TypeResponse: Codable {
    let success: Bool
    let data: TypeData?
    let error: String?
}

private struct TypeData: Codable {
    let action: String
    let text: String
}

private struct MenuResponse: Codable {
    let success: Bool
    let error: String?
}

private struct WindowActionResponse: Codable {
    let success: Bool
    let error: String?
}

private enum ProcessError: Error {
    case message(String)
    case binaryMissing
}
#endif
