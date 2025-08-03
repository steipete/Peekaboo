import AppKit
import PeekabooUICore
import SwiftUI

@main
struct PeekabooInspectorApp: App {
    @StateObject private var overlayManager = OverlayManager()
    @MainActor private let overlayWindowController: OverlayWindowController

    @MainActor
    init() {
        let manager = OverlayManager()
        self._overlayManager = StateObject(wrappedValue: manager)
        self.overlayWindowController = OverlayWindowController(overlayManager: manager)
    }

    var body: some Scene {
        WindowGroup("Peekaboo Inspector") {
            InspectorView()
                .environmentObject(self.overlayManager)
                .onAppear {
                    self.overlayWindowController.startMonitoringScreenChanges()
                }
                .onDisappear {
                    self.overlayWindowController.stopMonitoringScreenChanges()
                    self.overlayWindowController.removeOverlays()
                }
                .onChange(of: self.overlayManager.isOverlayActive) { _, _ in
                    self.overlayWindowController.updateVisibility()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
    }
}
