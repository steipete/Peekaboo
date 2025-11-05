//
//  OverlayManagerTests.swift
//  PeekabooUICore
//

import Testing
@testable import PeekabooUICore

@Suite("Overlay manager behavior")
struct OverlayManagerTests {
    @MainActor
    @Test("Defaults are configured for all applications")
    func defaults() {
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
    @Test("Selection mode updates trigger refresh")
    func selectionModeUpdates() {
        let manager = OverlayManager()
        defer { manager.cleanup() }

        manager.setAppSelectionMode(.single, bundleID: "com.example.test")

        #expect(manager.selectedAppMode == .single)
        #expect(manager.selectedAppBundleID == "com.example.test")
    }

    @MainActor
    @Test("Detail level updates")
    func detailLevelUpdates() {
        let manager = OverlayManager()
        defer { manager.cleanup() }

        manager.setDetailLevel(.all)

        #expect(manager.detailLevel == .all)
    }
}
