import PeekabooCore
import Testing
@testable import PeekabooCLI

struct WindowTargetCreationTests {
    @Test
    func `app + windowTitle creates .applicationAndTitle`() {
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

    @Test
    func `app + windowIndex creates .index`() {
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

    @Test
    func `app only creates .application`() {
        var options = WindowIdentificationOptions()
        options.app = "Safari"

        switch options.createTarget() {
        case let .application(app):
            #expect(app == "Safari")
        default:
            Issue.record("Expected .application")
        }
    }

    @Test
    func `windowId creates .windowId`() {
        var options = WindowIdentificationOptions()
        options.windowId = 12345

        switch options.createTarget() {
        case let .windowId(id):
            #expect(id == 12345)
        default:
            Issue.record("Expected .windowId")
        }
    }

    @Test
    func `toWindowTarget prefers windowId without app`() throws {
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
