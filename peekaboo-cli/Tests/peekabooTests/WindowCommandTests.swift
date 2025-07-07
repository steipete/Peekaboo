import Foundation
import Testing
@testable import peekaboo

@available(macOS 14.0, *)
@Suite("WindowCommand Tests", .serialized)
struct WindowCommandTests {
    @Test
    func windowCommandHelp() async throws {
        let output = try await runPeekabooCommand(["window", "--help"])

        #expect(output.contains("Manipulate application windows"))
        #expect(output.contains("close"))
        #expect(output.contains("minimize"))
        #expect(output.contains("maximize"))
        #expect(output.contains("move"))
        #expect(output.contains("resize"))
        #expect(output.contains("set-bounds"))
        #expect(output.contains("focus"))
        #expect(output.contains("list"))
    }

    @Test
    func windowCloseHelp() async throws {
        let output = try await runPeekabooCommand(["window", "close", "--help"])

        #expect(output.contains("Close a window"))
        #expect(output.contains("--app"))
        #expect(output.contains("--window-title"))
        #expect(output.contains("--window-index"))
    }

    @Test
    func windowListCommand() async throws {
        // Test that window list delegates to list windows command
        let output = try await runPeekabooCommand(["window", "list", "--app", "Finder", "--json-output"])

        let data = try JSONDecoder().decode(JSONResponse.self, from: output.data(using: .utf8)!)
        #expect(data.success == true || data.error != nil) // Either succeeds or fails with proper error
    }

    @Test
    func windowCommandWithoutApp() async throws {
        // Test that window commands require --app
        let commands = ["close", "minimize", "maximize", "focus"]

        for command in commands {
            do {
                _ = try await self.runPeekabooCommand(["window", command])
                Issue.record("Expected command to fail without --app")
            } catch {
                // Expected to fail
                #expect(error.localizedDescription.contains("--app must be specified") ||
                    error.localizedDescription.contains("Exit status: 1"))
            }
        }
    }

    @Test
    func windowMoveRequiresCoordinates() async throws {
        do {
            _ = try await self.runPeekabooCommand(["window", "move", "--app", "Finder"])
            Issue.record("Expected command to fail without coordinates")
        } catch {
            // Expected to fail - missing required x and y
            #expect(error.localizedDescription.contains("Missing expected argument") ||
                error.localizedDescription.contains("Exit status: 64"))
        }
    }

    @Test
    func windowResizeRequiresDimensions() async throws {
        do {
            _ = try await self.runPeekabooCommand(["window", "resize", "--app", "Finder"])
            Issue.record("Expected command to fail without dimensions")
        } catch {
            // Expected to fail - missing required width and height
            #expect(error.localizedDescription.contains("Missing expected argument") ||
                error.localizedDescription.contains("Exit status: 64"))
        }
    }

    @Test
    func windowSetBoundsRequiresAllParameters() async throws {
        do {
            _ = try await self.runPeekabooCommand([
                "window",
                "set-bounds",
                "--app",
                "Finder",
                "--x",
                "100",
                "--y",
                "100",
            ])
            Issue.record("Expected command to fail without all parameters")
        } catch {
            // Expected to fail - missing required width and height
            #expect(error.localizedDescription.contains("Missing expected argument") ||
                error.localizedDescription.contains("Exit status: 64"))
        }
    }

    // Helper function to run peekaboo commands
    private func runPeekabooCommand(_ arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["run", "peekaboo"] + arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0, process.terminationStatus != 64 {
            throw TestError.commandFailed(status: process.terminationStatus, output: output)
        }

        return output
    }

    enum TestError: Error, LocalizedError {
        case commandFailed(status: Int32, output: String)

        var errorDescription: String? {
            switch self {
            case let .commandFailed(status, output):
                "Command failed with exit status: \(status). Output: \(output)"
            }
        }
    }
}

// MARK: - Local Integration Tests

@available(macOS 14.0, *)
@Suite("Window Command Local Integration Tests", .serialized)
struct WindowCommandLocalIntegrationTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true"))
    func windowMinimizeTextEdit() async throws {
        // This test requires TextEdit to be running and local permissions

        // First, ensure TextEdit is running and has a window
        let launchResult = try await runPeekabooCommand(["image", "--app", "TextEdit", "--json-output"])
        let launchData = try JSONDecoder().decode(JSONResponse.self, from: launchResult.data(using: .utf8)!)

        guard launchData.success else {
            Issue.record("TextEdit must be running for this test")
            return
        }

        // Try to minimize TextEdit window
        let result = try await runPeekabooCommand(["window", "minimize", "--app", "TextEdit", "--json-output"])
        let data = try JSONDecoder().decode(JSONResponse.self, from: result.data(using: .utf8)!)

        if let error = data.error {
            if error.code == "PERMISSION_ERROR_ACCESSIBILITY" {
                Issue.record("Accessibility permission required for window manipulation")
                return
            }
        }

        #expect(data.success == true)

        // Wait a bit for the animation
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true"))
    func windowMoveTextEdit() async throws {
        // This test requires TextEdit to be running and local permissions

        // Try to move TextEdit window
        let result = try await runPeekabooCommand([
            "window", "move",
            "--app", "TextEdit",
            "--x", "200",
            "--y", "200",
            "--json-output",
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: result.data(using: .utf8)!)

        if let error = data.error {
            if error.code == "PERMISSION_ERROR_ACCESSIBILITY" {
                Issue.record("Accessibility permission required for window manipulation")
                return
            }
        }

        #expect(data.success == true)

        if let responseData = data.data?.value as? [String: Any],
           let newBounds = responseData["new_bounds"] as? [String: Any]
        {
            #expect(newBounds["x"] as? Int == 200)
            #expect(newBounds["y"] as? Int == 200)
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true"))
    func windowFocusTextEdit() async throws {
        // This test requires TextEdit to be running

        // Try to focus TextEdit window
        let result = try await runPeekabooCommand([
            "window", "focus",
            "--app", "TextEdit",
            "--json-output",
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: result.data(using: .utf8)!)

        if let error = data.error {
            if error.code == "PERMISSION_ERROR_ACCESSIBILITY" {
                Issue.record("Accessibility permission required for window manipulation")
                return
            }
        }

        #expect(data.success == true)
    }

    // Helper function for local tests
    private func runPeekabooCommand(_ arguments: [String]) async throws -> String {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let executablePath = projectRoot
            .appendingPathComponent("peekaboo-cli")
            .appendingPathComponent(".build")
            .appendingPathComponent("debug")
            .appendingPathComponent("peekaboo")
            .path

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0, process.terminationStatus != 64, process.terminationStatus != 1 {
            throw TestError.commandFailed(status: process.terminationStatus, output: output)
        }

        return output
    }

    enum TestError: Error, LocalizedError {
        case commandFailed(status: Int32, output: String)

        var errorDescription: String? {
            switch self {
            case let .commandFailed(status, output):
                "Exit status: \(status)"
            }
        }
    }
}
