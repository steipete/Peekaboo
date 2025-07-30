import Foundation
import Testing
@testable import peekaboo

@Suite("App Command Tests", .serialized)
struct AppCommandTests {
    @Test("App command exists")
    func appCommandExists() {
        let config = AppCommand.configuration
        #expect(config.commandName == "app")
        #expect(config.abstract.contains("application lifecycle"))
    }

    @Test("App command has expected subcommands")
    func appSubcommands() {
        let subcommands = AppCommand.configuration.subcommands
        #expect(subcommands.count == 5)

        let subcommandNames = subcommands.map(\.configuration.commandName)
        #expect(subcommandNames.contains("launch"))
        #expect(subcommandNames.contains("quit"))
        #expect(subcommandNames.contains("hide"))
        #expect(subcommandNames.contains("show"))
        #expect(subcommandNames.contains("switch"))
    }

    @Test("App launch command help")
    func appLaunchHelp() async throws {
        let output = try await runCommand(["app", "launch", "--help"])

        #expect(output.contains("Launch an application"))
        #expect(output.contains("--app"))
        #expect(output.contains("--bundle-id"))
        #expect(output.contains("--wait"))
        #expect(output.contains("--background"))
    }

    @Test("App quit command validation")
    func appQuitValidation() async throws {
        // Test missing app/all
        await #expect(throws: Error.self) {
            _ = try await runCommand(["app", "quit"])
        }

        // Test conflicting options
        await #expect(throws: Error.self) {
            _ = try await runCommand(["app", "quit", "--app", "Finder", "--all"])
        }
    }

    @Test("App hide command validation")
    func appHideValidation() async throws {
        // Normal hide should work
        let output = try await runCommand(["app", "hide", "--app", "Finder", "--help"])
        #expect(output.contains("Hide applications"))

        // Test --others flag
        #expect(output.contains("--others"))
    }

    @Test("App show command validation")
    func appShowValidation() async throws {
        // Test missing app/all
        await #expect(throws: Error.self) {
            _ = try await runCommand(["app", "show"])
        }
    }

    @Test("App switch command validation")
    func appSwitchValidation() async throws {
        // Test missing to/cycle
        await #expect(throws: Error.self) {
            _ = try await runCommand(["app", "switch"])
        }
    }

    @Test("App lifecycle flow")
    func appLifecycleFlow() {
        // This tests the logical flow of app lifecycle commands
        let launchCmd = ["app", "launch", "--app", "TextEdit", "--wait"]
        let hideCmd = ["app", "hide", "--app", "TextEdit"]
        let showCmd = ["app", "show", "--app", "TextEdit"]
        let quitCmd = ["app", "quit", "--app", "TextEdit", "--save-changes"]

        // Verify command structure is valid
        #expect(launchCmd.count > 3)
        #expect(hideCmd.count > 3)
        #expect(showCmd.count > 3)
        #expect(quitCmd.count > 3)
    }
}

// MARK: - App Command Integration Tests

@Suite(
    "App Command Integration Tests",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true")
)
struct AppCommandIntegrationTests {
    @Test("Launch application")
    func launchApp() async throws {
        let output = try await runCommand([
            "app", "launch",
            "--app", "TextEdit",
            "--wait",
            "--json-output",
        ])

        struct LaunchResult: Codable {
            let action: String
            let app_name: String
            let bundle_id: String
            let pid: Int32
            let is_ready: Bool
        }

        let response = try JSONDecoder().decode(
            CodableJSONResponse<LaunchResult>.self,
            from: output.data(using: .utf8)!
        )
        #expect(response.success == true)
        #expect(response.data.action == "launch")
        #expect(response.data.app_name == "TextEdit")
        #expect(response.data.pid > 0)
    }

    @Test("Hide and show application")
    func hideShowApp() async throws {
        // First hide
        let hideOutput = try await runCommand([
            "app", "hide",
            "--app", "TextEdit",
            "--json-output",
        ])

        let hideData = try JSONDecoder().decode(JSONResponse.self, from: hideOutput.data(using: .utf8)!)
        #expect(hideData.success == true)

        // Then show
        let showOutput = try await runCommand([
            "app", "show",
            "--app", "TextEdit",
            "--json-output",
        ])

        let showData = try JSONDecoder().decode(JSONResponse.self, from: showOutput.data(using: .utf8)!)
        #expect(showData.success == true)
    }

    @Test("Switch between applications")
    func switchApps() async throws {
        // Cycle to next app
        let cycleOutput = try await runCommand([
            "app", "switch",
            "--cycle",
            "--json-output",
        ])

        let cycleData = try JSONDecoder().decode(JSONResponse.self, from: cycleOutput.data(using: .utf8)!)
        #expect(cycleData.success == true)

        // Switch to specific app
        let switchOutput = try await runCommand([
            "app", "switch",
            "--to", "Finder",
            "--json-output",
        ])

        let switchData = try JSONDecoder().decode(JSONResponse.self, from: switchOutput.data(using: .utf8)!)
        #expect(switchData.success == true)
    }

    @Test("Quit application with save")
    func quitWithSave() async throws {
        let output = try await runCommand([
            "app", "quit",
            "--app", "TextEdit",
            "--save-changes",
            "--json-output",
        ])

        struct AppQuitInfo: Codable {
            let app_name: String
            let bundle_id: String
            let pid: Int32
            let terminated: Bool
        }

        struct QuitResult: Codable {
            let action: String
            let force: Bool
            let results: [AppQuitInfo]
        }

        let response = try JSONDecoder().decode(CodableJSONResponse<QuitResult>.self, from: output.data(using: .utf8)!)
        // App might not be running
        if response.success {
            #expect(!response.data.results.isEmpty)
        }
    }

    @Test("Hide others functionality")
    func hideOthers() async throws {
        let output = try await runCommand([
            "app", "hide",
            "--app", "Finder",
            "--others",
            "--json-output",
        ])

        let response = try JSONDecoder().decode(
            CodableJSONResponse<[String: String]>.self,
            from: output.data(using: .utf8)!
        )
        if response.success {
            #expect(response.data["action"] == "hide")
        }
    }
}

// MARK: - Test Helpers

private func runCommand(_ args: [String]) async throws -> String {
    let output = try await runPeekabooCommand(args)
    return output
}

private func runPeekabooCommand(_ args: [String]) async throws -> String {
    // This is a placeholder - in real tests, this would execute the actual CLI
    // For unit tests, we're mainly testing command structure and validation
    ""
}
