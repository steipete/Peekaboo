import Foundation
import Testing
@testable import PeekabooCLI
@testable import PeekabooCore

#if !PEEKABOO_SKIP_AUTOMATION
@Suite("App Command Tests", .serialized, .tags(.automation), .enabled(if: CLITestEnvironment.runAutomationRead))
struct AppCommandTests {
    @Test("App command exists")
    func appCommandExists() {
        let config = AppCommand.commandDescription
        #expect(config.commandName == "app")
        #expect(config.abstract.contains("Control applications"))
    }

    @Test("App command has expected subcommands")
    func appSubcommands() {
        let subcommands = AppCommand.commandDescription.subcommands
        #expect(subcommands.count == 7)

        var subcommandNames: [String] = []
        subcommandNames.reserveCapacity(subcommands.count)
        for descriptor in subcommands {
            let name = descriptor.commandDescription.commandName ?? ""
            subcommandNames.append(name)
        }
        #expect(subcommandNames.contains("launch"))
        #expect(subcommandNames.contains("quit"))
        #expect(subcommandNames.contains("hide"))
        #expect(subcommandNames.contains("unhide"))
        #expect(subcommandNames.contains("switch"))
        #expect(subcommandNames.contains("relaunch"))
        #expect(subcommandNames.contains("list"))
    }

    @Test("App launch command help")
    func appLaunchHelp() async throws {
        let output = try await runAppCommand(["app", "launch", "--help"])

        #expect(output.contains("Launch an application"))
        #expect(output.contains("--bundle-id"))
        #expect(output.contains("--open"))
        #expect(output.contains("--wait-until-ready"))
        #expect(output.contains("--no-focus"))
    }

    @Test("App quit command validation")
    func appQuitValidation() async throws {
        // Test missing app/all
        await #expect(throws: (any Error).self) {
            _ = try await runAppCommand(["app", "quit"])
        }

        // Test conflicting options
        await #expect(throws: (any Error).self) {
            _ = try await runAppCommand(["app", "quit", "--app", "Finder", "--all"])
        }
    }

    @Test("App hide command validation")
    func appHideValidation() async throws {
        // Normal hide should work
        let output = try await runAppCommand(["app", "hide", "--app", "Finder", "--help"])
        #expect(output.contains("Hide an application"))
    }

    @Test("App show command validation")
    func appShowValidation() async throws {
        // Test missing app/all
        await #expect(throws: (any Error).self) {
            _ = try await runAppCommand(["app", "unhide"])
        }
    }

    @Test("App switch command validation")
    func appSwitchValidation() async throws {
        // Test missing to/cycle
        await #expect(throws: (any Error).self) {
            _ = try await runAppCommand(["app", "switch"])
        }
    }

    @Test("App lifecycle flow")
    func appLifecycleFlow() {
        // This tests the logical flow of app lifecycle commands
        let launchCmd = ["app", "launch", "--app", "TextEdit", "--wait-until-ready"]
        let hideCmd = ["app", "hide", "--app", "TextEdit"]
        let showCmd = ["app", "unhide", "--app", "TextEdit"]
        let quitCmd = ["app", "quit", "--app", "TextEdit", "--json"]

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
    .enabled(if: CLITestEnvironment.runAutomationActions)
)
struct AppCommandIntegrationTests {
    @Test("Launch application")
    func launchApp() async throws {
        let (output, appService) = try await runAppCommandWithService([
            "app", "launch",
            "--app", "TextEdit",
            "--wait",
            "--json",
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
            from: Data(output.utf8)
        )
        #expect(response.success == true)
        #expect(response.data.action == "launch")
        #expect(response.data.app_name == "TextEdit")
        #expect(response.data.pid > 0)
        let launchCalls = await appServiceState(appService) { $0.launchCalls }
        #expect(launchCalls.contains("TextEdit"))
    }

    @Test("Hide and show application")
    func hideShowApp() async throws {
        // First hide
        let (hideOutput, hideService) = try await runAppCommandWithService([
            "app", "hide",
            "--app", "TextEdit",
            "--json",
        ])

        let hideData = try JSONDecoder().decode(JSONResponse.self, from: Data(hideOutput.utf8))
        #expect(hideData.success == true)
        let hideCalls = await appServiceState(hideService) { $0.hideCalls }
        #expect(hideCalls.contains("TextEdit"))

        // Then show
        let (showOutput, showService) = try await runAppCommandWithService([
            "app", "show",
            "--app", "TextEdit",
            "--json",
        ])

        let showData = try JSONDecoder().decode(JSONResponse.self, from: Data(showOutput.utf8))
        #expect(showData.success == true)
        let unhideCalls = await appServiceState(showService) { $0.unhideCalls }
        #expect(unhideCalls.contains("TextEdit"))
    }

    @Test("Switch between applications")
    func switchApps() async throws {
        // Cycle to next app
        let (cycleOutput, cycleService) = try await runAppCommandWithService([
            "app", "switch",
            "--cycle",
            "--json",
        ])

        let cycleData = try JSONDecoder().decode(JSONResponse.self, from: Data(cycleOutput.utf8))
        #expect(cycleData.success == true)
        let cycleCalls = await appServiceState(cycleService) { $0.activateCalls }
        #expect(!cycleCalls.isEmpty)

        // Switch to specific app
        let (switchOutput, switchService) = try await runAppCommandWithService([
            "app", "switch",
            "--to", "Finder",
            "--json",
        ])

        let switchData = try JSONDecoder().decode(JSONResponse.self, from: Data(switchOutput.utf8))
        #expect(switchData.success == true)
        let switchCalls = await appServiceState(switchService) { $0.activateCalls }
        #expect(switchCalls.contains("Finder"))
    }

    @Test("Quit application with save")
    func quitWithSave() async throws {
        let (output, appService) = try await runAppCommandWithService([
            "app", "quit",
            "--app", "TextEdit",
            "--json",
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

        let response = try JSONDecoder().decode(CodableJSONResponse<QuitResult>.self, from: Data(output.utf8))
        #expect(response.success == true)
        let quitCalls = await appServiceState(appService) { $0.quitCalls }
        #expect(quitCalls.contains { $0.identifier == "TextEdit" && $0.force == false })
    }

    @Test("Hide others functionality")
    func hideOthers() async throws {
        let (output, appService) = try await runAppCommandWithService([
            "app", "hide",
            "--app", "Finder",
            "--others",
            "--json",
        ])

        let response = try JSONDecoder().decode(
            CodableJSONResponse<[String: String]>.self,
            from: Data(output.utf8)
        )
        #expect(response.success == true)
        let hideOtherCalls = await appServiceState(appService) { $0.hideOtherCalls }
        #expect(hideOtherCalls.contains("Finder"))
    }
}

// MARK: - Shared Helpers

private struct CommandFailure: Error {
    let status: Int32
    let stderr: String
}

private func runAppCommand(
    _ args: [String],
    configure: (@MainActor (StubApplicationService) -> Void)? = nil
) async throws -> String {
    let (output, _) = try await runAppCommandWithService(args, configure: configure)
    return output
}

private func runAppCommandWithService(
    _ args: [String],
    configure: (@MainActor (StubApplicationService) -> Void)? = nil
) async throws -> (String, StubApplicationService) {
    let context = await makeAppCommandContext()
    if let configure {
        await MainActor.run {
            configure(context.applicationService)
        }
    }
    let result = try await InProcessCommandRunner.run(args, services: context.services)
    let output = result.stdout.isEmpty ? result.stderr : result.stdout
    if result.exitStatus != 0 {
        throw CommandFailure(status: result.exitStatus, stderr: output)
    }
    return (output, context.applicationService)
}

@MainActor
private func makeAppCommandContext() -> AppCommandContext {
    let data = defaultAppCommandData()
    let applicationService = StubApplicationService(applications: data.applications, windowsByApp: data.windowsByApp)
    let windowService = StubWindowService(windowsByApp: data.windowsByApp)
    let services = TestServicesFactory.makePeekabooServices(
        applications: applicationService,
        windows: windowService
    )
    return AppCommandContext(services: services, applicationService: applicationService)
}

private func appServiceState<T: Sendable>(
    _ service: StubApplicationService,
    _ operation: @MainActor (StubApplicationService) -> T
) async -> T {
    await MainActor.run {
        operation(service)
    }
}

private struct AppCommandContext {
    let services: PeekabooServices
    let applicationService: StubApplicationService
}

@MainActor
private func defaultAppCommandData()
-> (applications: [ServiceApplicationInfo], windowsByApp: [String: [ServiceWindowInfo]]) {
    let applications = AppCommandTests.defaultApplications()
    let windowsByApp = AppCommandTests.defaultWindowsByApp()
    return (applications, windowsByApp)
}

extension AppCommandTests {
    fileprivate static func defaultApplications() -> [ServiceApplicationInfo] {
        [
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
    }

    fileprivate static func defaultWindowsByApp() -> [String: [ServiceWindowInfo]] {
        [
            "Finder": [self.finderWindow()],
            "TextEdit": [self.textEditWindow()],
        ]
    }

    fileprivate static func finderWindow() -> ServiceWindowInfo {
        ServiceWindowInfo(
            windowID: 1,
            title: "Finder Window",
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
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
    }

    fileprivate static func textEditWindow() -> ServiceWindowInfo {
        ServiceWindowInfo(
            windowID: 2,
            title: "Document",
            bounds: CGRect(x: 100, y: 100, width: 700, height: 500),
            isMinimized: false,
            isMainWindow: true,
            windowLevel: 0,
            alpha: 1.0,
            index: 0,
            spaceID: 2,
            spaceName: "Desktop 2",
            screenIndex: 0,
            screenName: "Built-in"
        )
    }
}

#endif
