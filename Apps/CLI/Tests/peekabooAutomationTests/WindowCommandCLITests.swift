import Foundation
import Testing
@testable import PeekabooCLI

#if !PEEKABOO_SKIP_AUTOMATION
@Suite("Window Command CLI Tests", .serialized, .tags(.automation), .enabled(if: CLITestEnvironment.runAutomationRead))
struct WindowCommandCLITests {
    @Test("Window help output")
    func windowHelpOutput() async throws {
        let (output, status) = try await runCommand(["window", "--help"])
        #expect(status == 0)

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
        let (output, status) = try await runCommand(["window", "close", "--help"])
        #expect(status == 0)

        #expect(output.contains("Close a window"))
        #expect(output.contains("--app"))
        #expect(output.contains("--window-title"))
        #expect(output.contains("--window-index"))
    }

    @Test("Window move help")
    func windowMoveHelp() async throws {
        let (output, status) = try await runCommand(["window", "move", "--help"])
        #expect(status == 0)

        #expect(output.contains("Move a window"))
        #expect(output.contains("--x"))
        #expect(output.contains("--y"))
    }

    @Test("Window resize help")
    func windowResizeHelp() async throws {
        let (output, status) = try await runCommand(["window", "resize", "--help"])
        #expect(status == 0)

        #expect(output.contains("Resize a window"))
        #expect(output.contains("--width"))
        #expect(output.contains("--height"))
    }

    @Test("Window list delegates to list windows")
    func windowListDelegation() async throws {
        let (output, status) = try await runCommand(["window", "list", "--app", "NonExistentApp", "--json-output"])
        #expect(status != 0)

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
        let (_, status) = try await self.runCommand(["window", "close", "--json-output"])
        #expect(status != 0)
    }

    @Test("Invalid window index")
    func invalidWindowIndex() async throws {
        let (output, status) = try await runCommand([
            "window",
            "close",
            "--app",
            "Finder",
            "--window-index",
            "999",
            "--json-output",
        ])
        #expect(status != 0)

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
            let result = try await runCommand(["window", operation, "--app", "NonExistentApp123", "--json-output"])
            #expect(result.status != 0)

            if let data = result.output.data(using: .utf8) {
                let response = try JSONDecoder().decode(JSONResponse.self, from: data)
                #expect(response.success == false)
                #expect(response.error?.code == "APP_NOT_FOUND")
            }
        }
    }

    // Helper to run commands
    private func runCommand(_ arguments: [String]) async throws -> (output: String, status: Int32) {
        do {
            let output = try await PeekabooCLITestRunner.runCommand(arguments)
            return (output, 0)
        } catch let error as PeekabooCLITestRunner.CommandError {
            return (error.output, error.status)
        }
    }
}

@Suite(
    "Window Command Integration Tests",
    .serialized,
    .enabled(if: CLITestEnvironment.runAutomationActions)
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
               let data = moveResponse.data as? [String: Any],
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
#endif
