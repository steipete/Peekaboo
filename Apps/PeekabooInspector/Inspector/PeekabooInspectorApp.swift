import AppKit
import SwiftUI
import PeekabooUICore

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
                .environmentObject(overlayManager)
                .onAppear {
                    overlayWindowController.startMonitoringScreenChanges()
                }
                .onDisappear {
                    overlayWindowController.stopMonitoringScreenChanges()
                    overlayWindowController.removeOverlays()
                }
                .onChange(of: overlayManager.isOverlayActive) { _, _ in
                    overlayWindowController.updateVisibility()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
    }
}
