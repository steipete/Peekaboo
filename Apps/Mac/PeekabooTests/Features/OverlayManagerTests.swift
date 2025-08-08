import Testing
import SwiftUI
import Combine
import PeekabooCore
import PeekabooUICore
import AXorcist

@Suite("OverlayManager Tests", .tags(.ui, .unit))
@MainActor
final class OverlayManagerTests {
    var manager: OverlayManager!
    var mockDelegate: MockOverlayManagerDelegate!
    private var cancellables: Set<AnyCancellable> = []

    init() {
        Task { @MainActor in
            self.manager = OverlayManager()
            self.mockDelegate = MockOverlayManagerDelegate()
            self.manager.delegate = self.mockDelegate
        }
    }

    @Test("Manager initializes with default state")
    func initialization() {
        #expect(manager.hoveredElement == nil)
        #expect(manager.selectedElement == nil)
        #expect(manager.applications.isEmpty)
        #expect(manager.isOverlayActive == false)
        #expect(manager.selectedAppMode == .all)
        #expect(manager.detailLevel == .moderate)
    }

    @Test("App selection mode can be changed")
    func appSelectionMode() {
        manager.setAppSelectionMode(.single, bundleID: "com.apple.finder")
        #expect(manager.selectedAppMode == .single)
        #expect(manager.selectedAppBundleID == "com.apple.finder")

        manager.setAppSelectionMode(.all)
        #expect(manager.selectedAppMode == .all)
        #expect(manager.selectedAppBundleID == nil)
    }

    @Test("Detail level can be changed")
    func detailLevel() {
        manager.setDetailLevel(.essential)
        #expect(manager.detailLevel == .essential)

        manager.setDetailLevel(.all)
        #expect(manager.detailLevel == .all)
    }
}

// MARK: - Mock Delegate

class MockOverlayManagerDelegate: OverlayManagerDelegate {
    var shouldShowElementHandler: ((OverlayManager.UIElement) -> Bool)?
    var didSelectElementHandler: ((OverlayManager.UIElement) -> Void)?
    var didHoverElementHandler: ((OverlayManager.UIElement?) -> Void)?

    func overlayManager(_ manager: OverlayManager, shouldShowElement element: OverlayManager.UIElement) -> Bool {
        return shouldShowElementHandler?(element) ?? true
    }

    func overlayManager(_ manager: OverlayManager, didSelectElement element: OverlayManager.UIElement) {
        didSelectElementHandler?(element)
    }

    func overlayManager(_ manager: OverlayManager, didHoverElement element: OverlayManager.UIElement?) {
        didHoverElementHandler?(element)
    }
}
