import PeekabooCore
import Testing
@testable import PeekabooCLI

@Suite("WindowTarget creation")
struct WindowTargetCreationTests {
    @Test("app + windowTitle creates .applicationAndTitle")
    func appTitleCreatesApplicationAndTitle() {
        var options = WindowIdentificationOptions()
        options.app = "Safari"
        options.windowTitle = "GitHub"

        switch options.createTarget() {
        case let .applicationAndTitle(app, title):
            #expect(app == "Safari")
            #expect(title == "GitHub")
        default:
            Issue.record("Expected .applicationAndTitle")
        }
    }

    @Test("app + windowIndex creates .index")
    func appIndexCreatesIndex() {
        var options = WindowIdentificationOptions()
        options.app = "Safari"
        options.windowIndex = 0

        switch options.createTarget() {
        case let .index(app, index):
            #expect(app == "Safari")
            #expect(index == 0)
        default:
            Issue.record("Expected .index")
        }
    }

    @Test("app only creates .application")
    func appOnlyCreatesApplication() {
        var options = WindowIdentificationOptions()
        options.app = "Safari"

        switch options.createTarget() {
        case let .application(app):
            #expect(app == "Safari")
        default:
            Issue.record("Expected .application")
        }
    }

    @Test("windowId creates .windowId")
    func windowIdCreatesWindowId() {
        var options = WindowIdentificationOptions()
        options.windowId = 12345

        switch options.createTarget() {
        case let .windowId(id):
            #expect(id == 12345)
        default:
            Issue.record("Expected .windowId")
        }
    }

    @Test("toWindowTarget prefers windowId without app")
    func toWindowTargetPrefersWindowId() throws {
        var options = WindowIdentificationOptions()
        options.windowId = 12345
        let target = try options.toWindowTarget()
        switch target {
        case let .windowId(id):
            #expect(id == 12345)
        default:
            Issue.record("Expected .windowId")
        }
    }
}
