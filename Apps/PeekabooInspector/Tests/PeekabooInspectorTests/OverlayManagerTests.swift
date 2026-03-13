import PeekabooUICore
import Testing
@testable import PeekabooInspector

struct OverlayManagerTests {
    @MainActor
    @Test
    func `OverlayManager defaults to inactive overlay state`() {
        let manager = OverlayManager(enableMonitoring: false)
        defer { manager.cleanup() }

        #expect(manager.isOverlayActive == false)
        #expect(manager.detailLevel == .moderate)
        #expect(manager.applications.isEmpty)
    }

    @MainActor
    @Test
    func `Changing detail level and app mode updates manager state`() {
        let manager = OverlayManager(enableMonitoring: false)
        defer { manager.cleanup() }

        manager.setDetailLevel(.all)
        manager.setAppSelectionMode(.single, bundleID: "com.example.fake")

        #expect(manager.detailLevel == .all)
        #expect(manager.selectedAppMode == .single)
        #expect(manager.selectedAppBundleID == "com.example.fake")
    }
}
