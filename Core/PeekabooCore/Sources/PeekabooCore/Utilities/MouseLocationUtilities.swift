import AppKit
import AXorcist
import os

/// Utilities for finding applications based on mouse location
@MainActor
public enum MouseLocationUtilities {
    private static let logger = Logger(subsystem: "boo.peekaboo.core", category: "MouseLocation")

    /// Find the application that has a window at the current mouse location
    /// - Returns: The application at the mouse location, or the frontmost app as fallback
    public static func findApplicationAtMouseLocation() -> NSRunningApplication? {
        let mouseLocation = NSEvent.mouseLocation

        // Performance optimization: Start with frontmost app if mouse is over it
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let axApp = AXUIElementCreateApplication(frontApp.processIdentifier)
            let appElement = Element(axApp)

            if let windows = appElement.windows() {
                for window in windows {
                    if let frame = window.frame(),
                       frame.contains(mouseLocation)
                    {
                        self.logger.debug("Mouse is over frontmost app: \(frontApp.localizedName ?? "unknown")")
                        return frontApp
                    }
                }
            }
        }

        // If not found in frontmost, check other visible apps
        // Only check apps that are likely to have visible windows
        let visibleApps = NSWorkspace.shared.runningApplications.filter { app in
            app.activationPolicy == .regular &&
                !app.isHidden &&
                app.bundleIdentifier != nil
        }

        for app in visibleApps {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            let appElement = Element(axApp)

            // Check if this app has a window at the mouse location
            if let windows = appElement.windows() {
                for window in windows {
                    if let frame = window.frame(),
                       frame.contains(mouseLocation)
                    {
                        self.logger.debug("Found app at mouse location: \(app.localizedName ?? app.bundleIdentifier!)")
                        return app
                    }
                }
            }
        }

        // If no app found at mouse location, fall back to frontmost
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        self.logger.debug("No app at mouse location, using frontmost: \(frontmostApp?.localizedName ?? "unknown")")
        return frontmostApp
    }
}
