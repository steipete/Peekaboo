import AppKit
import PeekabooCore
import PeekabooUICore
import SwiftUI

struct InspectorView: View {
    @Environment(Permissions.self) private var permissions

    var body: some View {
        PeekabooUICore.InspectorView(
            configuration: {
                var config = InspectorConfiguration()
                config.showPermissionAlert = false // We handle permissions differently
                config.enableOverlay = false // Disable overlay for now to test if it's causing the issue
                config.defaultDetailLevel = .moderate
                return config
            }()
        )
        .onAppear {
            Task {
                await permissions.check()
            }
            permissions.startMonitoring()
        }
        .onDisappear {
            permissions.stopMonitoring()
        }
    }
}