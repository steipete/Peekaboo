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

    @Test
    func `validation can allow snapshot-only focus target`() throws {
        var options = WindowIdentificationOptions()
        try options.validate(allowMissingTarget: true)

        options.windowIndex = -1
        #expect(throws: (any Error).self) {
            try options.validate(allowMissingTarget: true)
        }
    }

    @Test
    func `snapshot window target prefers window id`() {
        let snapshot = UIAutomationSnapshot(
            applicationName: "Example",
            applicationBundleId: "com.example.app",
            windowTitle: "Main",
            windowID: 42
        )

        switch windowTarget(from: snapshot) {
        case let .windowId(windowID):
            #expect(windowID == 42)
        default:
            Issue.record("Expected .windowId")
        }
    }

    @Test
    func `snapshot window target falls back to app and title`() {
        let snapshot = UIAutomationSnapshot(
            applicationName: "Example",
            applicationBundleId: "com.example.app",
            windowTitle: "Main"
        )

        switch windowTarget(from: snapshot) {
        case let .applicationAndTitle(app, title):
            #expect(app == "com.example.app")
            #expect(title == "Main")
        default:
            Issue.record("Expected .applicationAndTitle")
        }
    }

    @Test
    func `snapshot display name prefers application name`() {
        let snapshot = UIAutomationSnapshot(
            applicationName: "Example",
            applicationBundleId: "com.example.app"
        )

        #expect(windowDisplayName(from: snapshot, snapshotId: "snapshot-1") == "Example")
    }
}
