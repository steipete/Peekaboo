import AXorcist
import Combine
import PeekabooCore
import PeekabooUICore
import SwiftUI
import Testing

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
        #expect(self.manager.hoveredElement == nil)
        #expect(self.manager.selectedElement == nil)
        #expect(self.manager.applications.isEmpty)
        #expect(self.manager.isOverlayActive == false)
        #expect(self.manager.selectedAppMode == .all)
        #expect(self.manager.detailLevel == .moderate)
    }

    @Test("App selection mode can be changed")
    func appSelectionMode() {
        self.manager.setAppSelectionMode(.single, bundleID: "com.apple.finder")
        #expect(self.manager.selectedAppMode == .single)
        #expect(self.manager.selectedAppBundleID == "com.apple.finder")

        self.manager.setAppSelectionMode(.all)
        #expect(self.manager.selectedAppMode == .all)
        #expect(self.manager.selectedAppBundleID == nil)
    }

    @Test("Detail level can be changed")
    func detailLevel() {
        self.manager.setDetailLevel(.essential)
        #expect(self.manager.detailLevel == .essential)

        self.manager.setDetailLevel(.all)
        #expect(self.manager.detailLevel == .all)
    }
}

// MARK: - Mock Delegate

class MockOverlayManagerDelegate: OverlayManagerDelegate {
    var shouldShowElementHandler: ((OverlayManager.UIElement) -> Bool)?
    var didSelectElementHandler: ((OverlayManager.UIElement) -> Void)?
    var didHoverElementHandler: ((OverlayManager.UIElement?) -> Void)?

    func overlayManager(_ manager: OverlayManager, shouldShowElement element: OverlayManager.UIElement) -> Bool {
        self.shouldShowElementHandler?(element) ?? true
    }

    func overlayManager(_ manager: OverlayManager, didSelectElement element: OverlayManager.UIElement) {
        self.didSelectElementHandler?(element)
    }

    func overlayManager(_ manager: OverlayManager, didHoverElement element: OverlayManager.UIElement?) {
        self.didHoverElementHandler?(element)
    }
}
