import AppKit
import SwiftUI

@main
struct PeekabooInspectorApp: App {
    @StateObject private var overlayManager = OverlayManager()

    var body: some Scene {
        WindowGroup("Peekaboo Inspector") {
            InspectorView()
                .environmentObject(self.overlayManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
    }
}
