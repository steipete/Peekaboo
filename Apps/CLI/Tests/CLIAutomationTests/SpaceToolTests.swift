import CoreGraphics
import Foundation
import MCP
import Testing
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
        let stubSpaceService = SpaceToolStubSpaceService(spaces: self.sampleSpaces())
        let tool = SpaceTool(testingSpaceService: stubSpaceService)
        let args = ToolArguments(from: [
            "action": "move-window",
            "app": context.appName,
            "to_current": true,
        ])

        let response = try await tool.execute(arguments: args)

        #expect(response.isError == false)
        #expect(stubSpaceService.moveToCurrentCalls == [CGWindowID(context.windowInfo.windowID)])
        if let meta = response.meta?.objectValue {
            #expect(meta["window_title"]?.stringValue == context.windowInfo.title)
            #expect(meta["window_id"]?.doubleValue == Double(context.windowInfo.windowID))
            #expect(meta["moved_to_current"]?.boolValue == true)
        } else {
            Issue.record("Expected metadata for move-window response")
        }
    }

    @Test("move-window --to + --follow moves and switches spaces")
    func moveWindowToSpecificSpace() async throws {
        let context = await self.makeTestContext()
        let stubSpaceService = SpaceToolStubSpaceService(spaces: self.sampleSpaces())
        let tool = SpaceTool(testingSpaceService: stubSpaceService)
        let args = ToolArguments(from: [
            "action": "move-window",
            "app": context.appName,
            "to": 2,
            "follow": true,
        ])

        let response = try await tool.execute(arguments: args)

        #expect(response.isError == false)
        #expect(stubSpaceService.moveWindowCalls.count == 1)
        if let call = stubSpaceService.moveWindowCalls.first {
            #expect(call.windowID == CGWindowID(context.windowInfo.windowID))
            #expect(call.spaceID == self.sampleSpaces()[1].id)
        }
        #expect(stubSpaceService.switchCalls == [self.sampleSpaces()[1].id])

        if let meta = response.meta?.objectValue {
            #expect(meta["target_space_number"]?.doubleValue == 2)
            #expect(meta["target_space_id"]?.doubleValue == Double(self.sampleSpaces()[1].id))
            #expect(meta["followed"]?.boolValue == true)
        } else {
            Issue.record("Expected metadata for move-window follow response")
        }
    }

    // MARK: - Helpers

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

    private func sampleSpaces() -> [SpaceInfo] {
        [
            SpaceInfo(
                id: 1,
                type: .user,
                isActive: true,
                displayID: nil,
                name: "Desktop 1",
                ownerPIDs: []
            ),
            SpaceInfo(
                id: 2,
                type: .user,
                isActive: false,
                displayID: nil,
                name: "Desktop 2",
                ownerPIDs: []
            ),
        ]
    }
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
