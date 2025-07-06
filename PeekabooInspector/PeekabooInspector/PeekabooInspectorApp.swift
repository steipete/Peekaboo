import SwiftUI
import AppKit

@main
struct PeekabooInspectorApp: App {
    @StateObject private var overlayManager = OverlayManager()
    
    var body: some Scene {
        WindowGroup("Peekaboo Inspector") {
            InspectorView()
                .environmentObject(overlayManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
    }
}