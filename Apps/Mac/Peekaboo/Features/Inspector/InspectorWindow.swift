//
//  InspectorWindow.swift
//  Peekaboo
//
//  Simplified Inspector window for debugging

import SwiftUI
import AppKit

struct InspectorWindow: View {
    @Environment(Permissions.self) private var permissions
    
    var body: some View {
        InspectorView()
            .frame(minWidth: 400, minHeight: 600)
            .background(WindowAccessor(windowAction: { window in
                // Ensure this is a proper window, not a panel
                window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
                window.level = .normal
                window.collectionBehavior = [.managed, .participatesInCycle]
                window.isMovableByWindowBackground = false
                window.titlebarAppearsTransparent = false
                window.standardWindowButton(.closeButton)?.isEnabled = true
                window.standardWindowButton(.miniaturizeButton)?.isEnabled = true
                window.standardWindowButton(.zoomButton)?.isEnabled = true
                
                // CRITICAL: Accept mouse events for local monitor to work
                window.ignoresMouseEvents = false
                
                // Make it a key window that can receive events
                window.makeKeyAndOrderFront(nil)
                
                // Set window identifier for debugging
                window.identifier = NSUserInterfaceItemIdentifier("inspector")
            }))
            .onAppear {
                Task {
                    await permissions.check()
                }
            }
    }
}

// Window accessor to configure NSWindow properties
struct WindowAccessor: NSViewRepresentable {
    let windowAction: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // Don't try to access window here - it's not available yet
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Window is available here - configure it
        if let window = nsView.window {
            self.windowAction(window)
        }
    }
}

#Preview {
    InspectorWindow()
        .environment(PeekabooSettings())
        .environment(Permissions())
}