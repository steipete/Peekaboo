//
//  OverlayManagerTests.swift
//  PeekabooUICore
//

import Testing
@testable import PeekabooUICore

struct OverlayManagerTests {
    @MainActor
    @Test
    func `Defaults are configured for all applications`() {
        let manager = OverlayManager()
        defer { manager.cleanup() }

        #expect(manager.hoveredElement == nil)
        #expect(manager.selectedElement == nil)
        #expect(manager.applications.isEmpty)
        #expect(manager.isOverlayActive == false)
        #expect(manager.selectedAppMode == .all)
        #expect(manager.selectedAppBundleID == nil)
        #expect(manager.detailLevel == .moderate)
    }

    @MainActor
    @Test
    func `Selection mode updates trigger refresh`() {
        let manager = OverlayManager()
        defer { manager.cleanup() }

        manager.setAppSelectionMode(.single, bundleID: "com.example.test")

        #expect(manager.selectedAppMode == .single)
        #expect(manager.selectedAppBundleID == "com.example.test")
    }

    @MainActor
    @Test
    func `Detail level updates`() {
        let manager = OverlayManager()
        defer { manager.cleanup() }

        manager.setDetailLevel(.all)

        #expect(manager.detailLevel == .all)
    }
}
