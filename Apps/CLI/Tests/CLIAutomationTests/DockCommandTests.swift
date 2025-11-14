import CoreGraphics
import Foundation
import Testing
@testable import PeekabooCLI
@testable import PeekabooCore

#if !PEEKABOO_SKIP_AUTOMATION
@Suite("DockCommand", .tags(.automation), .enabled(if: CLITestEnvironment.runAutomationRead))
struct DockCommandTests {
    @Test("Help output is consistent with V1")
    func helpOutput() async throws {
        let result = try await self.runCommand(["dock", "--help"])
        let output = result.output

        // Check for expected help content
        #expect(output.contains("Interact with the macOS Dock"))
        #expect(output.contains("launch"))
        #expect(output.contains("right-click"))
        #expect(output.contains("hide"))
        #expect(output.contains("show"))
        #expect(output.contains("list"))
    }

    @Test("List command JSON structure")
    func listCommandJSON() async throws {
        let result = try await self.runCommand(["dock", "list", "--json-output"])
        let output = result.output

        // Parse JSON
        let jsonData = Data(output.utf8)
        let response = try JSONDecoder().decode(JSONResponse.self, from: jsonData)

        #expect(response.success == true)
        // For now, just check success since we don't have access to the response data structure
        // This would need to be updated based on the actual dock command response format
    }

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
        let applications = StubApplicationService(applications: [])
        let dockItems = [
            DockItem(
                index: 0,
                title: "Finder",
                itemType: .application,
                isRunning: true,
                bundleIdentifier: "com.apple.finder",
                position: CGPoint(x: 0, y: 0),
                size: CGSize(width: 64, height: 64)
            ),
        ]
        let dockService = StubDockService(items: dockItems, autoHidden: false)
        return TestServicesFactory.makePeekabooServices(
            applications: applications,
            windows: StubWindowService(windowsByApp: [:]),
            menu: StubMenuService(menusByApp: [:]),
            dialogs: StubDialogService(),
            dock: dockService
        )
    }
}
#endif
