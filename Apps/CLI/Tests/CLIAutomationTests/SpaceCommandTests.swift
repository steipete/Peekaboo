import CoreGraphics
import Foundation
import Testing
@testable import PeekabooCLI
@testable import PeekabooCore

#if !PEEKABOO_SKIP_AUTOMATION

// MARK: - Read-only scenarios

@Suite(
    "Space Command Read Tests",
    .serialized,
    .tags(.automation),
    .enabled(if: CLITestEnvironment.runAutomationRead)
)
struct SpaceCommandReadTests {
    @Test("space command exists in help")
    func spaceCommandInHelp() async throws {
        let output = try await self.runPeekaboo(["--help"])
        #expect(output.contains("space"))
        #expect(output.contains("Manage macOS Spaces"))
    }

    @Test("space command help shows subcommands")
    func spaceCommandHelp() async throws {
        let output = try await self.runPeekaboo(["space", "--help"])
        #expect(output.contains("Manage macOS Spaces (virtual desktops)"))
        #expect(output.contains("list"))
        #expect(output.contains("switch"))
        #expect(output.contains("move-window"))
    }

    @Test("space switch command help")
    func spaceSwitchHelp() async throws {
        let output = try await self.runPeekaboo(["space", "switch", "--help"])
        #expect(output.contains("Switch to a different Space"))
        #expect(output.contains("--to"))
    }

    @Test("space list command")
    func spaceListCommand() async throws {
        let output = try await self.runPeekaboo(["space", "list"])
        #expect(!output.isEmpty)
    }

    @Test("space list with JSON output")
    func spaceListJSON() async throws {
        let output = try await self.runPeekaboo(["space", "list", "--json-output"])
        let response = try JSONDecoder().decode(SpaceListResponse.self, from: output.data(using: .utf8)!)
        #expect(response.success)
    }

    @Test("space list detailed flag")
    func spaceListDetailed() async throws {
        let output = try await self.runPeekaboo(["space", "list", "--detailed"])
        #expect(output.contains("Space"))
    }

    @Test("space switch requires --to parameter")
    func spaceSwitchRequiresDestination() {
        #expect(throws: (any Error).self) {
            try CLIOutputCapture.suppressStderr {
                _ = try SwitchSubcommand.parse([])
            }
        }
    }

    @Test("space switch rejects non-numeric parameters")
    func spaceSwitchRejectsNonNumeric() {
        #expect(throws: (any Error).self) {
            try CLIOutputCapture.suppressStderr {
                _ = try SwitchSubcommand.parse(["--to", "abc"])
            }
        }
    }

    @Test("space move-window requires app parameter")
    func spaceMoveWindowRequiresApp() {
        #expect(throws: (any Error).self) {
            try CLIOutputCapture.suppressStderr {
                _ = try MoveWindowSubcommand.parse(["--to", "2"])
            }
        }
    }

    @Test("space move-window requires destination")
    func spaceMoveWindowRequiresDestination() {
        #expect(throws: (any Error).self) {
            try CLIOutputCapture.suppressStderr {
                _ = try MoveWindowSubcommand.parse(["--app", "Finder"])
            }
        }
    }

    @Test("space move-window parses follow option")
    func spaceMoveWindowParsesFollowOption() throws {
        let command = try MoveWindowSubcommand.parse([
            "--app", "Finder",
            "--to", "3",
            "--follow",
        ])

        #expect(command.app == "Finder")
        #expect(command.to == 3)
        #expect(command.follow == true)
    }

    private func runPeekaboo(_ arguments: [String]) async throws -> String {
        let context = await self.makeTestContext()
        let result = try await InProcessCommandRunner.run(
            arguments,
            services: context.services,
            spaceService: context.spaceService
        )
        return result.stdout
    }

    @MainActor
    func makeTestContext() -> (services: PeekabooServices, spaceService: SpaceCommandSpaceService) {
        let applications = Self.testApplications()
        let windowsByApp = Self.windowsByApp()

        let services = TestServicesFactory.makePeekabooServices(
            applications: StubApplicationService(applications: applications, windowsByApp: windowsByApp),
            windows: StubWindowService(windowsByApp: windowsByApp),
            menu: StubMenuService(menusByApp: [:]),
            dialogs: StubDialogService(),
            screens: []
        )

        let spaceInfos = Self.spaceInfos()
        let windowSpaces = Self.windowSpaces(from: spaceInfos)
        let spaceService = StubSpaceService(spaces: spaceInfos, windowSpaces: windowSpaces)

        return (services, spaceService)
    }
}

private extension SpaceCommandReadTests {
    static func testApplications() -> [ServiceApplicationInfo] {
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

    static func windowsByApp() -> [String: [ServiceWindowInfo]] {
        [
            "Finder": [Self.finderWindow()],
            "TextEdit": [Self.textEditWindow()],
        ]
    }

    static func finderWindow() -> ServiceWindowInfo {
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

    static func textEditWindow() -> ServiceWindowInfo {
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

    static func spaceInfos() -> [SpaceInfo] {
        [
            SpaceInfo(
                id: 1,
                type: .user,
                isActive: true,
                displayID: 1,
                name: "Desktop 1",
                ownerPIDs: [101]
            ),
            SpaceInfo(
                id: 2,
                type: .user,
                isActive: false,
                displayID: 1,
                name: "Desktop 2",
                ownerPIDs: [202]
            ),
        ]
    }

    static func windowSpaces(from infos: [SpaceInfo]) -> [Int: [SpaceInfo]] {
        [
            1: [infos[0]],
            2: [infos[1]],
        ]
    }
}

// MARK: - Actions that mutate Spaces

@Suite(
    "Space Command Action Tests",
    .serialized,
    .tags(.automation),
    .enabled(if: CLITestEnvironment.runAutomationActions)
)
struct SpaceCommandActionTests {
    @Test("space switch with valid number")
    func spaceSwitchValid() async throws {
        let context = await self.makeSpaceContext()
        let result = try await self.runSpaceCommand([
            "space", "switch",
            "--to", "1",
            "--json-output",
        ], context: context)
        #expect(result.exitStatus == 0)
        let response = try JSONDecoder().decode(
            SpaceActionResponse.self,
            from: self.output(from: result).data(using: .utf8)!
        )
        #expect(response.success)
        let switchCalls = await self.spaceState(context) { $0.switchCalls }
        #expect(switchCalls.contains(1))
    }

    @Test("space move-window to current Space")
    func spaceMoveWindowToCurrent() async throws {
        let context = await self.makeSpaceContext()
        let result = try await self.runSpaceCommand([
            "space", "move-window",
            "--app", "Finder",
            "--to-current",
            "--json-output",
        ], context: context)
        #expect(result.exitStatus == 0)
        let response = try JSONDecoder().decode(
            WindowSpaceActionResponse.self,
            from: self.output(from: result).data(using: .utf8)!
        )
        #expect(response.success)
        let moveCalls = await self.spaceState(context) { $0.moveToCurrentCalls }
        #expect(!moveCalls.isEmpty)
    }

    @Test("space move-window with follow option")
    func spaceMoveWindowWithFollow() async throws {
        let context = await self.makeSpaceContext()
        let result = try await self.runSpaceCommand([
            "space", "move-window",
            "--app", "TextEdit",
            "--to", "1",
            "--follow",
            "--json-output",
        ], context: context)
        #expect(result.exitStatus == 0)
        let response = try JSONDecoder().decode(
            WindowSpaceActionResponse.self,
            from: self.output(from: result).data(using: .utf8)!
        )
        #expect(response.success)
        let moveCalls = await self.spaceState(context) { $0.moveWindowCalls }
        #expect(moveCalls.contains { $0.spaceID == 1 })
    }

    private func runSpaceCommand(
        _ arguments: [String],
        context: SpaceHarnessContext
    ) async throws -> CommandRunResult {
        try await SpaceCommandEnvironment.withSpaceService(context.spaceService) {
            try await InProcessCommandRunner.run(
                arguments,
                services: context.services,
                spaceService: context.spaceService
            )
        }
    }

    @MainActor
    private func makeSpaceContext() async -> SpaceHarnessContext {
        let base = SpaceCommandReadTests().makeTestContext()
        let spaces = await base.spaceService.getAllSpaces()
        let spaceService = StubSpaceService(spaces: spaces, windowSpaces: [:])
        let services = base.services
        return SpaceHarnessContext(services: services, spaceService: spaceService)
    }

    private func output(from result: CommandRunResult) -> String {
        result.stdout.isEmpty ? result.stderr : result.stdout
    }

    private func spaceState<T: Sendable>(
        _ context: SpaceHarnessContext,
        _ operation: @MainActor (StubSpaceService) -> T
    ) async -> T {
        await MainActor.run {
            operation(context.spaceService)
        }
    }
}

private struct SpaceHarnessContext {
    let services: PeekabooServices
    let spaceService: StubSpaceService
}

// MARK: - Response types shared by tests

private struct SpaceListResponse: Codable {
    let success: Bool
    let data: SpaceListData?
    let error: String?
}

private struct SpaceListData: Codable {
    let spaces: [SpaceData]
}

private struct SpaceData: Codable {
    let id: UInt64
    let type: String
    let is_active: Bool?
    let display_id: UInt32?
}

private struct SpaceActionResponse: Codable {
    let success: Bool
    let data: SpaceActionData?
    let error: String?
}

private struct SpaceActionData: Codable {
    let action: String
    let success: Bool
    let space_id: UInt64
    let space_number: Int
}

private struct WindowSpaceActionResponse: Codable {
    let success: Bool
    let data: WindowSpaceActionData?
    let error: String?
}

private struct WindowSpaceActionData: Codable {
    let action: String
    let success: Bool
    let window_id: UInt32
    let window_title: String
    let space_id: UInt64?
    let space_number: Int?
    let moved_to_current: Bool?
    let followed: Bool?
}
#endif
