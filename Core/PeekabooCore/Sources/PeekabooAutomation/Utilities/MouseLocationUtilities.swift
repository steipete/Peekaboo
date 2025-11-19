import AppKit
import AXorcist
import os

/// Wrapper delegating to AXorcist AppLocator to avoid duplicate AX walking.
@MainActor
public enum MouseLocationUtilities {
    private static let logger = Logger(subsystem: "boo.peekaboo.core", category: "MouseLocation")

    public static func findApplicationAtMouseLocation() -> NSRunningApplication? {
        let app = AppLocator.app()
        if let name = app?.localizedName ?? app?.bundleIdentifier {
            self.logger.debug("Mouse is over app: \(name, privacy: .public)")
        } else {
            self.logger.debug("MouseLocationUtilities found no app; returning nil")
        }
        return app
    }
}
