//
//  PeekabooServicesVisualizerInit.swift
//  PeekabooCore
//

import Foundation

extension PeekabooServices {
    /// Ensures the visualizer client is connected if running from CLI
    /// This should be called early in CLI initialization
    public func ensureVisualizerConnection() {
        // Check if we're running as CLI (not Mac app)
        let isMacApp = Bundle.main.bundleIdentifier?.hasPrefix("boo.peekaboo.mac") == true
        
        if !isMacApp {
            // Force connection by accessing the visualization client
            VisualizationClient.shared.connect()
            
            // Also trigger service initialization to ensure connections are made
            _ = self.screenCapture
            _ = self.automation
            _ = self.windows
            _ = self.menu
            _ = self.dialogs
        }
    }
}