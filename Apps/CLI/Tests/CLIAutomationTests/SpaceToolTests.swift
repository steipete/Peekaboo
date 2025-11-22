import CoreGraphics
import Foundation
import MCP
import TachikomaMCP
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooCore

#if !PEEKABOO_SKIP_AUTOMATION
@Suite(
    "SpaceTool Move Window Tests",
    .serialized,
    .tags(.automation)
)
struct SpaceToolMoveWindowTests {
    @Test("move-window --to_current refreshes metadata and issues move call")
    func moveWindowToCurrentSpace() async throws {
        let context = await self.makeTestContext()
        await MainActor.run {
            MCPToolContext.configureDefaultContext {
                MCPToolContext(services: context.services)
            }
        }
        let stubSpaceService = SpaceToolStubSpaceService(spaces: [])
        let tool = SpaceTool(testingSpaceService: stubSpaceService)
        let args = self.makeArguments([
            "action": .string("move-window"),
            "app": .string(context.appName),
            "to_current": .bool(true),
        ])

        let response = try await tool.execute(arguments: args)

        // Current behavior: SpaceTool issues a move-to-current request even when the
        // space service reports no spaces (the service decides whether to error).
        #expect(response.isError == false)
        #expect(stubSpaceService.moveToCurrentCalls == [CGWindowID(context.windowInfo.windowID)])
    }

    // MARK: - Helpers

    private func makeArguments(_ payload: [String: Value]) -> ToolArguments {
        ToolArguments(value: .object(payload))
    }

    @MainActor
    private func makeTestContext() -> (services: PeekabooServices, appName: String, windowInfo: ServiceWindowInfo) {
        let appName = "TextEdit"
        let bundleID = "com.apple.TextEdit"
        let appInfo = ServiceApplicationInfo(
            processIdentifier: 999,
            bundleIdentifier: bundleID,
            name: appName,
            bundlePath: "/System/Applications/TextEdit.app",
            isActive: true,
            isHidden: false,
            windowCount: 1
        )

        let windowInfo = ServiceWindowInfo(
            windowID: 4040,
            title: "Document",
            bounds: CGRect(x: 100, y: 100, width: 600, height: 400),
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

        let windowsByApp = [appName: [windowInfo]]
        let services = TestServicesFactory.makePeekabooServices(
            applications: StubApplicationService(applications: [appInfo], windowsByApp: windowsByApp),
            windows: StubWindowService(windowsByApp: windowsByApp)
        )

        return (services, appName, windowInfo)
    }

    private func sampleSpaces() -> [SpaceInfo] { [] }
}

@MainActor
final class SpaceToolStubSpaceService: SpaceManaging {
    var spaces: [SpaceInfo]
    var moveToCurrentCalls: [CGWindowID] = []
    var moveWindowCalls: [(windowID: CGWindowID, spaceID: CGSSpaceID)] = []
    var switchCalls: [CGSSpaceID] = []

    init(spaces: [SpaceInfo]) {
        self.spaces = spaces
    }

    func getAllSpaces() -> [SpaceInfo] {
        self.spaces
    }

    func moveWindowToCurrentSpace(windowID: CGWindowID) throws {
        self.moveToCurrentCalls.append(windowID)
    }

    func moveWindowToSpace(windowID: CGWindowID, spaceID: CGSSpaceID) throws {
        self.moveWindowCalls.append((windowID, spaceID))
    }

    func switchToSpace(_ spaceID: CGSSpaceID) async throws {
        self.switchCalls.append(spaceID)
    }
}
#endif
