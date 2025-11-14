//
//  PeekabooServicesVisualizerInit.swift
//  PeekabooCore
//

import Foundation
import PeekabooVisualizer

extension PeekabooServices {
    /// Prepares the visualizer event bridge when running from the CLI.
    /// Call this early during startup so the shared storage exists before commands emit events.
    @MainActor
    public func ensureVisualizerConnection() {
        let isMacApp = Bundle.main.bundleIdentifier?.hasPrefix("boo.peekaboo.mac") == true

        guard !isMacApp else { return }

        VisualizationClient.shared.connect()

        // Touch frequently used services so they are ready once commands execute.
        _ = self.screenCapture
        _ = self.automation
        _ = self.windows
        _ = self.menu
        _ = self.dialogs
    }
}
