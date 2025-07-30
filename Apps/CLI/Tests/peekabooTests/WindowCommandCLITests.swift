import Foundation
import Testing
@testable import peekaboo

@Suite("Window Command CLI Tests", .serialized)
struct WindowCommandCLITests {
    @Test("Window help output")
    func windowHelpOutput() async throws {
        let output = try await runCommand(["window", "--help"])

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

    @Test("Window close help")
    func windowCloseHelp() async throws {
        let output = try await runCommand(["window", "close", "--help"])

        #expect(output.contains("Close a window"))
        #expect(output.contains("--app"))
        #expect(output.contains("--window-title"))
        #expect(output.contains("--window-index"))
    }

    @Test("Window move help")
    func windowMoveHelp() async throws {
        let output = try await runCommand(["window", "move", "--help"])

        #expect(output.contains("Move a window"))
        #expect(output.contains("--x"))
        #expect(output.contains("--y"))
    }

    @Test("Window resize help")
    func windowResizeHelp() async throws {
        let output = try await runCommand(["window", "resize", "--help"])

        #expect(output.contains("Resize a window"))
        #expect(output.contains("--width"))
        #expect(output.contains("--height"))
    }

    @Test("Window list delegates to list windows")
    func windowListDelegation() async throws {
        let output = try await runCommand(["window", "list", "--app", "NonExistentApp", "--json-output"])

        // Should get JSON output
        #expect(output.contains("{"))
        #expect(output.contains("}"))

        // Parse and verify structure
        if let data = output.data(using: .utf8) {
            let response = try JSONDecoder().decode(JSONResponse.self, from: data)
            #expect(response.success == false)
            #expect(response.error?.code == "APP_NOT_FOUND")
        }
    }

    @Test("Missing required app parameter")
    func missingAppParameter() async throws {
        do {
            _ = try await self.runCommand(["window", "close", "--json-output"])
            Issue.record("Expected command to fail")
        } catch {
            // Expected to fail
            #expect(true)
        }
    }

    @Test("Invalid window index")
    func invalidWindowIndex() async throws {
        let output = try await runCommand([
            "window",
            "close",
            "--app",
            "Finder",
            "--window-index",
            "999",
            "--json-output",
        ])

        if let data = output.data(using: .utf8) {
            let response = try JSONDecoder().decode(JSONResponse.self, from: data)
            #expect(response.success == false)
            #expect(response.error != nil)
        }
    }

    @Test("Window operation with non-existent app")
    func nonExistentApp() async throws {
        let operations = ["close", "minimize", "maximize", "focus"]

        for operation in operations {
            let output = try await runCommand(["window", operation, "--app", "NonExistentApp123", "--json-output"])

            if let data = output.data(using: .utf8) {
                let response = try JSONDecoder().decode(JSONResponse.self, from: data)
                #expect(response.success == false)
                #expect(response.error?.code == "APP_NOT_FOUND")
            }
        }
    }

    // Helper to run commands
    private func runCommand(_ arguments: [String]) async throws -> String {
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

        // Allow expected exit codes
        if process.terminationStatus != 0, process.terminationStatus != 1, process.terminationStatus != 64 {
            throw CommandError.unexpectedExitCode(process.terminationStatus)
        }

        return output
    }

    enum CommandError: Error {
        case unexpectedExitCode(Int32)
    }
}

@Suite(
    "Window Command Integration Tests",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true")
)
struct WindowCommandLocalTests {
    @Test("Window operations with TextEdit")
    func textEditWindowOperations() async throws {
        // Ensure TextEdit is running
        _ = try? await self.runBuiltCommand(["image", "--app", "TextEdit", "--json-output"])

        // Try to focus TextEdit
        let focusOutput = try await runBuiltCommand(["window", "focus", "--app", "TextEdit", "--json-output"])
        let focusResponse = try JSONDecoder().decode(JSONResponse.self, from: focusOutput.data(using: .utf8)!)

        if focusResponse.error?.code == "PERMISSION_ERROR_ACCESSIBILITY" {
            Issue.record("Accessibility permission required")
            return
        }

        if focusResponse.success {
            // Try moving the window
            let moveOutput = try await runBuiltCommand([
                "window", "move",
                "--app", "TextEdit",
                "--x", "200",
                "--y", "200",
                "--json-output",
            ])

            let moveResponse = try JSONDecoder().decode(JSONResponse.self, from: moveOutput.data(using: .utf8)!)

            if moveResponse.success,
               let data = moveResponse.data?.value as? [String: Any],
               let bounds = data["new_bounds"] as? [String: Any] {
                #expect(bounds["x"] as? Int == 200)
                #expect(bounds["y"] as? Int == 200)
            }
        }
    }

    // Helper for local tests using built binary
    private func runBuiltCommand(_ arguments: [String]) async throws -> String {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let binaryPath = projectRoot
            .appendingPathComponent(".build/debug/peekaboo")
            .path

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
