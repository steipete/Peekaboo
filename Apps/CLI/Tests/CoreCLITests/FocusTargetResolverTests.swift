import CoreGraphics
import PeekabooCore
import Testing
@testable import PeekabooCLI

@Suite("Focus target resolution")
struct FocusTargetResolverTests {
    @Test("explicit windowID always wins")
    func explicitWindowIdWins() {
        let snapshot = UIAutomationSnapshot(
            applicationBundleId: "com.example.app",
            windowTitle: "X",
            windowID: 42
        )
        let result = FocusTargetResolver.resolve(
            windowID: 777,
            snapshot: snapshot,
            applicationName: "Safari",
            windowTitle: "GitHub"
        )

        #expect(result == .windowId(777))
    }

    @Test("snapshot windowID wins when present")
    func snapshotWindowIdWins() {
        let snapshot = UIAutomationSnapshot(
            applicationBundleId: "com.example.app",
            windowTitle: "X",
            windowID: 42
        )
        let result = FocusTargetResolver.resolve(
            windowID: nil,
            snapshot: snapshot,
            applicationName: "Safari",
            windowTitle: "GitHub"
        )

        #expect(result == .windowId(42))
    }

    @Test("snapshot without windowID falls back to bundleId + title")
    func snapshotWithoutWindowIdFallsBackToBestWindow() {
        let snapshot = UIAutomationSnapshot(
            applicationBundleId: "com.example.app",
            windowTitle: "My Window",
            windowID: nil
        )
        let result = FocusTargetResolver.resolve(
            windowID: nil,
            snapshot: snapshot,
            applicationName: nil,
            windowTitle: nil
        )

        #expect(result == .bestWindow(applicationName: "com.example.app", windowTitle: "My Window"))
    }

    @Test("explicit app/title override snapshot metadata when windowID missing")
    func explicitAppTitleOverrideSnapshotWhenWindowIdMissing() {
        let snapshot = UIAutomationSnapshot(
            applicationBundleId: "com.example.app",
            windowTitle: "Old Title",
            windowID: nil
        )
        let result = FocusTargetResolver.resolve(
            windowID: nil,
            snapshot: snapshot,
            applicationName: "Safari",
            windowTitle: "GitHub"
        )

        #expect(result == .bestWindow(applicationName: "Safari", windowTitle: "GitHub"))
    }

    @Test("no snapshot, app resolves to best window")
    func appWithoutSnapshotResolves() {
        let result = FocusTargetResolver.resolve(
            windowID: nil,
            snapshot: nil,
            applicationName: "Safari",
            windowTitle: nil
        )

        #expect(result == .bestWindow(applicationName: "Safari", windowTitle: nil))
    }

    @Test("no inputs returns nil")
    func noInputsReturnsNil() {
        let result = FocusTargetResolver.resolve(
            windowID: nil,
            snapshot: nil,
            applicationName: nil,
            windowTitle: nil
        )

        #expect(result == nil)
    }
}
