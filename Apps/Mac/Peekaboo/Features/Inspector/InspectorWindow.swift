import SwiftUI

/// Window wrapper for the Inspector feature
struct InspectorWindow: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(PeekabooSettings.self) private var settings
    @Environment(Permissions.self) private var permissions
    @StateObject private var overlayManager = OverlayManager()

    var body: some View {
        InspectorView()
            .environmentObject(self.overlayManager)
            .frame(minWidth: 400, minHeight: 600)
            .onAppear {
                // Check permissions when window appears
                Task {
                    await self.permissions.check()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenWindow.inspector"))) { _ in
                // Open the window
                DispatchQueue.main.async {
                    self.openWindow(id: "inspector")
                }
            }
    }
}

#Preview {
    InspectorWindow()
        .environment(PeekabooSettings())
        .environment(Permissions())
}
