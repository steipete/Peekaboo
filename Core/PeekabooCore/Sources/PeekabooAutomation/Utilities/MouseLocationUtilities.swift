import AppKit
import AXorcist
import os

/// Wrapper delegating to AXorcist AppLocator to avoid duplicate AX walking.
@MainActor
public enum MouseLocationUtilities {
    private static let logger = Logger(subsystem: "boo.peekaboo.core", category: "MouseLocation")
    private static var appProvider: () -> NSRunningApplication? = { AppLocator.app() }
    private static var frontmostProvider: () -> NSRunningApplication? = { NSWorkspace.shared.frontmostApplication }

    public static func findApplicationAtMouseLocation() -> NSRunningApplication? {
        if let app = self.appProvider() {
            if let name = app.localizedName ?? app.bundleIdentifier {
                self.logger.debug("Mouse is over app: \(name, privacy: .public)")
            }
            return app
        }

        let fallback = self.frontmostProvider()
        if let name = fallback?.localizedName ?? fallback?.bundleIdentifier {
            self.logger.debug("Using frontmost app as fallback: \(name, privacy: .public)")
        } else {
            self.logger.debug("MouseLocationUtilities found no app; returning nil")
        }
        return fallback
    }
}

#if DEBUG
extension MouseLocationUtilities {
    /// Allow tests to override app detection.
    static func setAppProvidersForTesting(
        appProvider: @escaping () -> NSRunningApplication?,
        frontmostProvider: @escaping () -> NSRunningApplication?)
    {
        self.appProvider = appProvider
        self.frontmostProvider = frontmostProvider
    }

    static func resetAppProvidersForTesting() {
        self.appProvider = { AppLocator.app() }
        self.frontmostProvider = { NSWorkspace.shared.frontmostApplication }
    }
}
#endif
