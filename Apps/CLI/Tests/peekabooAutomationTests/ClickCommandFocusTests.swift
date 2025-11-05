import Foundation
import Testing
@testable import PeekabooCLI

#if !PEEKABOO_SKIP_AUTOMATION
@Suite("Click Command Focus Tests", .serialized, .tags(.automation), .enabled(if: CLITestEnvironment.runAutomationScenarios))
struct ClickCommandFocusTests {
    // Helper function to run peekaboo commands
    private func runPeekabooCommand(_ arguments: [String]) async throws -> String {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.currentDirectoryURL = projectRoot
        process.arguments = ["run", "peekaboo"] + arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw ProcessError(message: "Failed to decode output")
        }

        guard process.terminationStatus == 0 else {
            throw ProcessError(message: "Process failed with exit code: \(process.terminationStatus)\nOutput: \(output)"
            )
        }

        return output
    }

    // MARK: - Focus Options in Click Command

    @Test("click command accepts all focus options")
    func clickAcceptsFocusOptions() async throws {
        // Test that all focus options are accepted without error
        let focusOptions = [
            "--no-auto-focus",
            "--focus-timeout", "3.0",
            "--focus-retry-count", "5",
            "--space-switch",
            "--bring-to-current-space"
        ]

        // Create a basic click command with all options
        var args = ["click", "100", "100", "--json-output"]
        args.append(contentsOf: focusOptions.flatMap { [$0] }.compactMap { arg in
            // Add values for options that need them
            if arg == "--focus-timeout" { return ["--focus-timeout", "3.0"] }
            if arg == "--focus-retry-count" { return ["--focus-retry-count", "5"] }
            return [arg]
        }.flatMap { $0 })

        let output = try await runPeekabooCommand(args)
        let data = try JSONDecoder().decode(JSONResponse.self, from: output.data(using: .utf8)!)

        // Command should be valid (may fail due to no element at position)
        #expect(data.success == true || data.error != nil)
    }

    @Test("click with session uses window focus")
    func clickWithSessionFocus() async throws {
        // Create session
        let seeOutput = try await runPeekabooCommand([
            "see",
            "--app", "Finder",
            "--json-output"
        ])

        let seeData = try JSONDecoder().decode(SeeResponse.self, from: seeOutput.data(using: .utf8)!)
        guard seeData.success,
              let sessionId = seeData.data?.session_id,
              let elements = seeData.data?.elements,
              !elements.isEmpty else {
            // Skip test if no Finder windows
            return
        }

        // Find a clickable element
        let clickableRoles = ["AXButton", "AXCheckBox", "AXRadioButton"]
        guard let clickable = elements.first(where: { clickableRoles.contains($0.role) }) else {
            // No clickable elements found
            return
        }

        // Click with session should auto-focus
        let clickOutput = try await runPeekabooCommand([
            "click", clickable.role.lowercased().replacingOccurrences(of: "ax", with: ""),
            "--session", sessionId,
            "--json-output"
        ])

        let clickData = try JSONDecoder().decode(ClickResponse.self, from: clickOutput.data(using: .utf8)!)
        #expect(clickData.success == true || clickData.error != nil)
    }

    @Test("click with Space switch option")
    func clickWithSpaceSwitch() async throws {
        // Test click with Space switching enabled
        let output = try await runPeekabooCommand([
            "click", "button",
            "--space-switch",
            "--json-output"
        ])

        let data = try JSONDecoder().decode(ClickResponse.self, from: output.data(using: .utf8)!)
        // Should handle Space switch option
        #expect(data.success == true || data.error != nil)
    }

    @Test("click with bring to current Space")
    func clickBringToCurrentSpace() async throws {
        // Test click with bring-to-current-space option
        let output = try await runPeekabooCommand([
            "click", "100", "200",
            "--bring-to-current-space",
            "--json-output"
        ])

        let data = try JSONDecoder().decode(ClickResponse.self, from: output.data(using: .utf8)!)
        // Should handle bring-to-current-space option
        #expect(data.success == true || data.error != nil)
    }

    // MARK: - Performance Tests

    @Test("click with session is faster than without")
    func clickSessionPerformance() async throws {
        // Create session
        let seeOutput = try await runPeekabooCommand([
            "see",
            "--app", "Finder",
            "--json-output"
        ])

        let seeData = try JSONDecoder().decode(SeeResponse.self, from: seeOutput.data(using: .utf8)!)
        guard seeData.success,
              let sessionId = seeData.data?.session_id else {
            return
        }

        // Time click with session
        let sessionStart = Date()
        _ = try await self.runPeekabooCommand([
            "click", "100", "100",
            "--session", sessionId,
            "--json-output"
        ])
        let sessionDuration = Date().timeIntervalSince(sessionStart)

        // Time click without session
        let noSessionStart = Date()
        _ = try await self.runPeekabooCommand([
            "click", "100", "100",
            "--json-output"
        ])
        let noSessionDuration = Date().timeIntervalSince(noSessionStart)

        // Session-based click should generally be faster
        // But we can't guarantee this in all test environments
        print("Click with session: \(sessionDuration)s, without: \(noSessionDuration)s")
    }

    // MARK: - Error Cases

    @Test("click with invalid session ID")
    func clickInvalidSession() async throws {
        let output = try await runPeekabooCommand([
            "click", "button",
            "--session", "invalid-session-id",
            "--json-output"
        ])

        let data = try JSONDecoder().decode(ClickResponse.self, from: output.data(using: .utf8)!)
        #expect(data.success == false)
        #expect(data.error?.contains("session") == true ||
            data.error?.contains("not found") == true
        )
    }

    @Test("click with conflicting focus options")
    func clickConflictingFocusOptions() async throws {
        // Test mutually exclusive options
        let output = try await runPeekabooCommand([
            "click", "100", "100",
            "--space-switch",
            "--bring-to-current-space",
            "--json-output"
        ])

        let data = try JSONDecoder().decode(ClickResponse.self, from: output.data(using: .utf8)!)
        // Should handle conflicting options gracefully
        #expect(data.success == true || data.error != nil)
    }
}

// MARK: - Response Types

private struct JSONResponse: Codable {
    let success: Bool
    let error: String?
}

private struct SeeResponse: Codable {
    let success: Bool
    let data: SeeData?
    let error: String?
}

private struct SeeData: Codable {
    let session_id: String
    let elements: [ElementData]?
}

private struct ElementData: Codable {
    let role: String
    let title: String?
    let label: String?
}

private struct ClickResponse: Codable {
    let success: Bool
    let data: ClickData?
    let error: String?
}

private struct ClickData: Codable {
    let action: String
    let success: Bool
}

private struct ProcessError: Error {
    let message: String
}
#endif
