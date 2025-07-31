import AppKit
import PeekabooCore
import PeekabooUICore
import SwiftUI

struct InspectorView: View {
    @StateObject private var overlayManager = OverlayManager()
    @Environment(Permissions.self) private var permissions
    private let overlayWindowController: OverlayWindowController
    
    init() {
        let manager = OverlayManager()
        self._overlayManager = StateObject(wrappedValue: manager)
        self.overlayWindowController = OverlayWindowController(overlayManager: manager)
    }

    var body: some View {
        PeekabooUICore.InspectorView(
            configuration: {
                var config = InspectorConfiguration()
                config.showPermissionAlert = false // We handle permissions differently
                config.enableOverlay = true
                config.defaultDetailLevel = .moderate
                return config
            }()
        )
        .environmentObject(overlayManager)
        .onAppear {
            Task {
                await permissions.check()
            }
            permissions.startMonitoring()
            overlayWindowController.startMonitoringScreenChanges()
        }
        .onDisappear {
            permissions.stopMonitoring()
            overlayWindowController.stopMonitoringScreenChanges()
            overlayWindowController.removeOverlays()
        }
        .onChange(of: overlayManager.isOverlayActive) { _, isActive in
            overlayWindowController.updateVisibility()
        }
    }
}