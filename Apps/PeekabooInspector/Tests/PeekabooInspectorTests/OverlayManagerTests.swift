import PeekabooUICore
import Testing
@testable import PeekabooInspector

@Suite("Peekaboo Inspector smoke tests")
struct OverlayManagerTests {
    @MainActor
    @Test("OverlayManager defaults to inactive overlay state")
    func overlayManagerDefaults() {
        let manager = OverlayManager(enableMonitoring: false)
        defer { manager.cleanup() }

        #expect(manager.isOverlayActive == false)
        #expect(manager.detailLevel == .moderate)
        #expect(manager.applications.isEmpty)
    }

    @MainActor
    @Test("Changing detail level and app mode updates manager state")
    func overlayManagerConfigurationChangesPersist() {
        let manager = OverlayManager(enableMonitoring: false)
        defer { manager.cleanup() }

        manager.setDetailLevel(.all)
        manager.setAppSelectionMode(.single, bundleID: "com.example.fake")

        #expect(manager.detailLevel == .all)
        #expect(manager.selectedAppMode == .single)
        #expect(manager.selectedAppBundleID == "com.example.fake")
    }
}
