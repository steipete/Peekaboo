import SwiftUI

/// Window wrapper for the Inspector feature
struct InspectorWindow: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(PeekabooSettings.self) private var settings
    @Environment(Permissions.self) private var permissions

    var body: some View {
        InspectorView()
            .frame(minWidth: 400, minHeight: 600)
            .background(WindowAccessor { window in
                // Configure window immediately when it's available
                configureWindow(window)
            })
            .onAppear {
                // Check permissions when window appears
                Task {
                    await self.permissions.check()
                }
                
                // Ensure the window is properly configured
                // Use a slight delay to ensure the window is fully created
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Find the Inspector window - it might not have the title set yet
                    if let window = NSApp.windows.first(where: { 
                        $0.title == "Inspector" || 
                        $0.identifier?.rawValue == "inspector" ||
                        ($0.contentView?.subviews.first as? NSHostingView<InspectorView>) != nil
                    }) {
                        // Ensure the window accepts events
                        window.ignoresMouseEvents = false
                        window.isReleasedWhenClosed = false
                        window.level = .normal
                        window.collectionBehavior = [.managed, .participatesInCycle, .fullScreenPrimary]
                        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
                        
                        // Make it active and key
                        window.makeKeyAndOrderFront(nil)
                        window.makeFirstResponder(window.contentView)
                        
                        // Ensure it can become key window
                        if !window.canBecomeKey {
                            print("Warning: Inspector window cannot become key window")
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenWindow.inspector"))) { _ in
                // Open the window
                DispatchQueue.main.async {
                    self.openWindow(id: "inspector")
                }
            }
            .task {
                // Set window identifier when view appears
                await MainActor.run {
                    if let window = NSApp.windows.first(where: { 
                        ($0.contentView?.subviews.first as? NSHostingView<InspectorWindow>) != nil
                    }) {
                        window.identifier = NSUserInterfaceItemIdentifier("inspector")
                    }
                }
            }
    }
    
    private func configureWindow(_ window: NSWindow) {
        // Ensure the window is interactive
        window.ignoresMouseEvents = false
        window.isReleasedWhenClosed = false
        window.level = .normal
        window.collectionBehavior = [.managed, .participatesInCycle, .fullScreenPrimary]
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.identifier = NSUserInterfaceItemIdentifier("inspector")
        
        // Ensure it can become key and main
        if window.canBecomeKey {
            window.makeKeyAndOrderFront(nil)
        }
        if let contentView = window.contentView {
            window.makeFirstResponder(contentView)
        }
    }
}

// Helper view to access the hosting window
struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                callback(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                callback(window)
            }
        }
    }
}

#Preview {
    InspectorWindow()
        .environment(PeekabooSettings())
        .environment(Permissions())
}
