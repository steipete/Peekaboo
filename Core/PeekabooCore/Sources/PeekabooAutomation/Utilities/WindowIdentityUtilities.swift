import AppKit
import AXorcist
import CoreGraphics
import Foundation
import os.log

/// Thin wrapper around AXorcist's AXWindowResolver to keep Peekaboo APIs stable
/// while de-duplicating AX/CG window logic.
public struct WindowIdentityInfo: Sendable {
    public let windowID: CGWindowID
    public let title: String?
    public let bounds: CGRect
    public let ownerPID: pid_t
    public let applicationName: String?
    public let bundleIdentifier: String?
    public let layer: Int
    public let alpha: CGFloat
    public let axIdentifier: String?

    public var isRenderable: Bool {
        self.bounds.width >= 50 && self.bounds.height >= 50 && self.alpha > 0
    }

    public var windowLayer: Int { self.layer } // Backward compatibility

    public var isMainWindow: Bool { self.layer == 0 && self.alpha > 0 }

    public var isDialog: Bool { self.layer >= 10 && self.layer < 1000 }

    public init(
        windowID: CGWindowID,
        title: String?,
        bounds: CGRect,
        ownerPID: pid_t,
        applicationName: String?,
        bundleIdentifier: String?,
        layer: Int,
        alpha: CGFloat,
        axIdentifier: String?)
    {
        self.windowID = windowID
        self.title = title
        self.bounds = bounds
        self.ownerPID = ownerPID
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
        self.layer = layer
        self.alpha = alpha
        self.axIdentifier = axIdentifier
    }

    // Convenience to preserve older label windowLayer
    public init(
        windowID: CGWindowID,
        title: String?,
        bounds: CGRect,
        ownerPID: pid_t,
        applicationName: String?,
        bundleIdentifier: String?,
        windowLayer: Int,
        alpha: CGFloat,
        axIdentifier: String?)
    {
        self.init(
            windowID: windowID,
            title: title,
            bounds: bounds,
            ownerPID: ownerPID,
            applicationName: applicationName,
            bundleIdentifier: bundleIdentifier,
            layer: windowLayer,
            alpha: alpha,
            axIdentifier: axIdentifier)
    }
}

@MainActor
public final class WindowIdentityService {
    private let resolver = AXWindowResolver()
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "WindowIdentity")

    public init() {}

    // MARK: - CGWindowID Extraction

    public func getWindowID(from windowElement: AXUIElement) -> CGWindowID? {
        self.resolver.windowID(from: windowElement)
    }

    public func getWindowID(from element: Element) -> CGWindowID? {
        self.resolver.windowID(from: element)
    }

    // MARK: - AXUIElement Lookup

    public func findWindow(byID windowID: CGWindowID, in app: NSRunningApplication) -> Element? {
        self.resolver.findWindow(by: windowID, in: app)
    }

    public func findWindow(byID windowID: CGWindowID) -> (window: Element, app: NSRunningApplication)? {
        self.resolver.findWindow(by: windowID)
    }

    // MARK: - Window Information

    public func getWindowInfo(windowID: CGWindowID) -> WindowIdentityInfo? {
        guard let info = self.resolver.windowInfo(windowID: windowID) else { return nil }

        // Compute AX identifier lazily.
        let axIdentifier = self.resolver.findWindow(by: windowID)?.window.identifier()

        return WindowIdentityInfo(
            windowID: info.windowID,
            title: info.title,
            bounds: info.bounds,
            ownerPID: info.ownerPID,
            applicationName: info.applicationName,
            bundleIdentifier: info.bundleIdentifier,
            layer: info.layer,
            alpha: info.alpha,
            axIdentifier: axIdentifier)
    }

    /// List windows for a running application using CGWindow metadata.
    public func getWindows(for app: NSRunningApplication) -> [WindowIdentityInfo] {
        guard let windowDicts = WindowInfoHelper.getWindows(for: app.processIdentifier) else {
            return []
        }

        return windowDicts.compactMap { dict in
            guard let id = dict[kCGWindowNumber as String] as? Int else { return nil }
            let title = dict[kCGWindowName as String] as? String
            let ownerPID = dict[kCGWindowOwnerPID as String] as? Int ?? Int(app.processIdentifier)
            let layer = dict[kCGWindowLayer as String] as? Int ?? 0
            let alpha = dict[kCGWindowAlpha as String] as? CGFloat ?? 1.0
            var boundsRect: CGRect = .zero
            if let bounds = dict[kCGWindowBounds as String] as? [String: CGFloat] {
                boundsRect = CGRect(
                    x: bounds["X"] ?? 0,
                    y: bounds["Y"] ?? 0,
                    width: bounds["Width"] ?? 0,
                    height: bounds["Height"] ?? 0)
            }

            return WindowIdentityInfo(
                windowID: CGWindowID(id),
                title: title,
                bounds: boundsRect,
                ownerPID: pid_t(ownerPID),
                applicationName: app.localizedName,
                bundleIdentifier: app.bundleIdentifier,
                layer: layer,
                alpha: alpha,
                axIdentifier: nil)
        }
    }

    // MARK: - Existence

    public func windowExists(windowID: CGWindowID) -> Bool {
        self.resolver.windowExists(windowID: windowID)
    }

    public func isWindowOnScreen(windowID: CGWindowID) -> Bool {
        self.windowExists(windowID: windowID)
    }

    // MARK: - AX attribute helpers

    public func windowIDFromAttribute(_ attribute: Any?) -> CGWindowID? {
        if let number = attribute as? NSNumber {
            return CGWindowID(number.intValue)
        }

        if let dict = attribute as? [String: Any],
           let windowNumber = dict[kCGWindowNumber as String] as? Int
        {
            return CGWindowID(windowNumber)
        }

        self.logger.debug("windowIDFromAttribute: unsupported attribute \(String(describing: attribute))")
        return nil
    }
}
