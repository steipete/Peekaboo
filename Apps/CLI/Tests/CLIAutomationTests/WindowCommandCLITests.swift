import Foundation
import Testing
@testable import PeekabooCLI
@testable import PeekabooCore

#if !PEEKABOO_SKIP_AUTOMATION
@Suite("Window Command CLI Tests", .serialized, .tags(.automation), .enabled(if: CLITestEnvironment.runAutomationRead))
struct WindowCommandCLITests {
    @Test("Window help output")
    func windowHelpOutput() async throws {
        let result = try await runCommand(["window", "--help"])
        #expect(result.status == 0)

        #expect(result.output.contains("Manipulate application windows"))
        #expect(result.output.contains("close"))
        #expect(result.output.contains("minimize"))
        #expect(result.output.contains("maximize"))
        #expect(result.output.contains("move"))
        #expect(result.output.contains("resize"))
        #expect(result.output.contains("set-bounds"))
        #expect(result.output.contains("focus"))
        #expect(result.output.contains("list"))
    }

    @Test("Window close help")
    func windowCloseHelp() async throws {
        let result = try await runCommand(["window", "close", "--help"])
        #expect(result.status == 0)

        #expect(result.output.contains("Close a window"))
        #expect(result.output.contains("--app"))
        #expect(result.output.contains("--window-title"))
        #expect(result.output.contains("--window-index"))
    }

    @Test("Window move help")
    func windowMoveHelp() async throws {
        let result = try await runCommand(["window", "move", "--help"])
        #expect(result.status == 0)

        #expect(result.output.contains("Move a window"))
        #expect(result.output.contains("--x"))
        #expect(result.output.contains("--y"))
    }

    @Test("Window resize help")
    func windowResizeHelp() async throws {
        let result = try await runCommand(["window", "resize", "--help"])
        #expect(result.status == 0)

        #expect(result.output.contains("Resize a window"))
        #expect(result.output.contains("--width"))
        #expect(result.output.contains("--height"))
    }

    @Test("Window list delegates to list windows")
    func windowListDelegation() async throws {
        let result = try await runCommand(["window", "list", "--app", "NonExistentApp", "--json-output"])
        #expect(result.status != 0)

        // Should get JSON output
        #expect(result.output.contains("{"))
        #expect(result.output.contains("}"))

        // Parse and verify structure
        if let data = result.output.data(using: .utf8) {
            let response = try JSONDecoder().decode(JSONResponse.self, from: data)
            #expect(response.success == false)
            #expect(response.error?.code == "APP_NOT_FOUND")
        }
    }

    @Test("Missing required app parameter")
    func missingAppParameter() async throws {
        let result = try await self.runCommand(["window", "close", "--json-output"])
        #expect(result.status != 0)
    }

    @Test("Invalid window index")
    func invalidWindowIndex() async throws {
        let result = try await runCommand([
            "window",
            "close",
            "--app",
            "Finder",
            "--window-index",
            "999",
            "--json-output",
        ])
        #expect(result.status != 0)

        if let data = result.output.data(using: .utf8) {
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
    private struct CommandResult {
        let output: String
        let status: Int32
    }

    private func runCommand(_ arguments: [String]) async throws -> CommandResult {
        let services = await self.makeTestServices()
        let result = try await InProcessCommandRunner.run(arguments, services: services)
        let output = result.stdout.isEmpty ? result.stderr : result.stdout
        return CommandResult(output: output, status: result.exitStatus)
    }

    @MainActor
    private func makeTestServices() -> PeekabooServices {
        let applications: [ServiceApplicationInfo] = [
            ServiceApplicationInfo(
                processIdentifier: 101,
                bundleIdentifier: "com.apple.finder",
                name: "Finder",
                bundlePath: "/System/Library/CoreServices/Finder.app",
                isActive: true,
                isHidden: false,
                windowCount: 1
            ),
            ServiceApplicationInfo(
                processIdentifier: 202,
                bundleIdentifier: "com.apple.TextEdit",
                name: "TextEdit",
                bundlePath: "/System/Applications/TextEdit.app",
                isActive: false,
                isHidden: false,
                windowCount: 1
            ),
        ]

        let finderWindow = ServiceWindowInfo(
            windowID: 1,
            title: "Finder Window",
            bounds: CGRect(x: 0, y: 0, width: 1024, height: 768),
            isMinimized: false,
            isMainWindow: true,
            windowLevel: 0,
            alpha: 1.0,
            index: 0,
            spaceID: 1,
            spaceName: "Desktop 1",
            screenIndex: 0,
            screenName: "Built-in"
        )

        let windowsByApp: [String: [ServiceWindowInfo]] = [
            "Finder": [finderWindow],
        ]

        return TestServicesFactory.makePeekabooServices(
            applications: StubApplicationService(applications: applications, windowsByApp: windowsByApp),
            windows: StubWindowService(windowsByApp: windowsByApp),
            menu: StubMenuService(menusByApp: [:]),
            dialogs: StubDialogService()
        )
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
    private func runBuiltCommand(
        _ arguments: [String],
        allowedExitStatuses: Set<Int32> = [0, 64]
    ) async throws -> String {
        let result = try await InProcessCommandRunner.runShared(
            arguments,
            allowedExitCodes: allowedExitStatuses
        )
        return result.combinedOutput
    }
}
#endif
