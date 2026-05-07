import PeekabooAutomation
import Testing
@testable import PeekabooAgentRuntime

struct MCPInteractionTargetTests {
    @Test
    func `window target prefers title over index`() throws {
        let target = MCPInteractionTarget(
            app: "Preview",
            pid: nil,
            windowTitle: "Main",
            windowIndex: 2,
            windowId: nil)

        switch try target.toWindowTarget() {
        case let .applicationAndTitle(app, title):
            #expect(app == "Preview")
            #expect(title == "Main")
        default:
            Issue.record("Expected application title target")
        }
    }

    @Test
    func `title only target ignores ambiguous index`() throws {
        let target = MCPInteractionTarget(
            app: nil,
            pid: nil,
            windowTitle: "Main",
            windowIndex: 2,
            windowId: nil)

        switch try target.toWindowTarget() {
        case let .title(title):
            #expect(title == "Main")
        default:
            Issue.record("Expected title target")
        }
    }
}
