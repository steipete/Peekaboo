import SwiftUI

/// Window wrapper for the Inspector feature
struct InspectorWindow: View {
    @Environment(PeekabooSettings.self) private var settings
    @Environment(Permissions.self) private var permissions
    @StateObject private var overlayManager = OverlayManager()
    
    var body: some View {
        InspectorView()
            .environmentObject(overlayManager)
            .frame(minWidth: 400, minHeight: 600)
            .onAppear {
                // Check permissions when window appears
                Task {
                    await permissions.check()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenWindow.inspector"))) { _ in
                // Window will automatically open when this notification is received
            }
    }
}

#Preview {
    InspectorWindow()
        .environment(PeekabooSettings())
        .environment(Permissions())
}