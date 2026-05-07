import AppKit
import AXorcist
import CoreGraphics
import Foundation
import os.log
import PeekabooFoundation

/**
 * Window management service providing window control operations using AXorcist.
 *
 * Handles window positioning, resizing, state changes (close/minimize/maximize), and focus
 * management with visual feedback integration. Built on AXorcist accessibility framework
 * for type-safe window operations across applications.
 *
 * ## Core Operations
 * - Window state: close, minimize, maximize, focus
 * - Positioning: move windows to specific coordinates
 * - Resizing: resize windows to specific dimensions
 * - Multi-window support with index-based targeting
 *
 * ## Usage Example
 * ```swift
 * let windowService = WindowManagementService()
 *
 * // Close specific window
 * try await windowService.closeWindow(
 *     target: WindowTarget(appIdentifier: "Safari", windowIndex: 1)
 * )
 *
 * // Move and resize window
 * try await windowService.moveWindow(
 *     target: WindowTarget(appIdentifier: "Terminal"),
 *     position: CGPoint(x: 100, y: 100)
 * )
 * ```
 *
 * - Important: Requires Accessibility permission for window operations
 * - Note: Performance varies 10-200ms depending on operation and application
 * - Since: PeekabooCore 1.0.0
 */
@MainActor
public final class WindowManagementService: WindowManagementServiceProtocol {
    let applicationService: any ApplicationServiceProtocol
    let windowIdentityService = WindowIdentityService()
    let cgInfoLookup: WindowCGInfoLookup
    let logger = Logger(subsystem: "boo.peekaboo.core", category: "WindowManagementService")
    let feedbackClient: any AutomationFeedbackClient

    public init(
        applicationService: (any ApplicationServiceProtocol)? = nil,
        feedbackClient: any AutomationFeedbackClient = NoopAutomationFeedbackClient())
    {
        self.applicationService = applicationService ?? ApplicationService()
        self.cgInfoLookup = WindowCGInfoLookup(windowIdentityService: self.windowIdentityService)
        self.feedbackClient = feedbackClient

        // Only connect to visualizer if we're not running inside the Mac app
        // The Mac app provides the visualizer service, not consumes it
        let isMacApp = Bundle.main.bundleIdentifier?.hasPrefix("boo.peekaboo.mac") == true
        if !isMacApp {
            self.logger.debug("Connecting to visualizer service (running as CLI/external tool)")
            self.feedbackClient.connect()
        } else {
            self.logger.debug("Skipping visualizer connection (running inside Mac app)")
        }
    }
}

@MainActor
extension WindowManagementService {
    public func closeWindow(target: WindowTarget) async throws {
        let trackedWindowID = try? await self.listWindows(target: target).first?.windowID
        let trackedAppIdentifier: String? = switch target {
        case let .application(appIdentifier): appIdentifier
        case let .applicationAndTitle(appIdentifier, _): appIdentifier
        case let .index(appIdentifier, _): appIdentifier
        default: nil
        }

        // Get window bounds for animation
        var windowBounds: CGRect?
        var closeButtonFrame: CGRect?

        let success = try await performWindowOperation(target: target) { window in
            if let closeButton = window.closeButton() {
                closeButtonFrame = closeButton.frame()
            }

            // Get window bounds before closing
            if let position = window.position(), let size = window.size() {
                windowBounds = CGRect(origin: position, size: size)
            }

            let result = window.closeWindow()

            // Show close animation if we have bounds
            if let bounds = windowBounds {
                Task {
                    _ = await self.feedbackClient.showWindowOperation(.close, windowRect: bounds, duration: 0.5)
                }
            }

            return result
        }

        if !success {
            throw OperationError.interactionFailed(
                action: "close window",
                reason: "Window close operation failed")
        }

        guard let trackedWindowID else { return }

        if await self.waitForWindowToDisappear(
            windowID: trackedWindowID,
            appIdentifier: trackedAppIdentifier,
            timeoutSeconds: 3.0)
        {
            return
        }

        self.logger
            .warning("Close succeeded but window still exists; trying hotkey fallbacks. windowID=\(trackedWindowID)")

        // Ensure the target window is key before sending hotkeys.
        _ = try? await self.performWindowOperation(target: target) { window in
            _ = window.focusWindow()
            return ()
        }

        try? InputDriver.hotkey(keys: ["cmd", "w"], holdDuration: 0.05)
        if await self.waitForWindowToDisappear(
            windowID: trackedWindowID,
            appIdentifier: trackedAppIdentifier,
            timeoutSeconds: 3.0)
        {
            return
        }

        try? InputDriver.hotkey(keys: ["cmd", "shift", "w"], holdDuration: 0.05)
        if await self.waitForWindowToDisappear(
            windowID: trackedWindowID,
            appIdentifier: trackedAppIdentifier,
            timeoutSeconds: 3.0)
        {
            return
        }

        if let closeButtonFrame {
            self.logger.warning(
                "Hotkey fallbacks failed; clicking close button frame as final fallback. windowID=\(trackedWindowID)")
            try? InputDriver.click(at: CGPoint(x: closeButtonFrame.midX, y: closeButtonFrame.midY))

            if await self.waitForWindowToDisappear(
                windowID: trackedWindowID,
                appIdentifier: trackedAppIdentifier,
                timeoutSeconds: 3.0)
            {
                return
            }
        }

        throw OperationError.interactionFailed(
            action: "close window",
            reason: "Close action completed but window remained visible (windowID=\(trackedWindowID))")
    }

    public func minimizeWindow(target: WindowTarget) async throws {
        // Get window bounds for animation
        var windowBounds: CGRect?

        let success = try await performWindowOperation(target: target) { window in
            // Get window bounds before minimizing
            if let position = window.position(), let size = window.size() {
                windowBounds = CGRect(origin: position, size: size)
            }

            let result = window.minimizeWindow()

            // Show minimize animation if we have bounds
            if let bounds = windowBounds {
                Task {
                    _ = await self.feedbackClient.showWindowOperation(.minimize, windowRect: bounds, duration: 0.5)
                }
            }

            return result
        }

        if !success {
            throw OperationError.interactionFailed(
                action: "minimize window",
                reason: "Window minimize operation failed")
        }
    }

    public func maximizeWindow(target: WindowTarget) async throws {
        // Get window bounds for animation
        var windowBounds: CGRect?

        let success = try await performWindowOperation(target: target) { window in
            // Get window bounds before maximizing
            if let position = window.position(), let size = window.size() {
                windowBounds = CGRect(origin: position, size: size)
            }

            let result = window.maximizeWindow()

            // Show maximize animation if we have bounds
            if let bounds = windowBounds {
                Task {
                    _ = await self.feedbackClient.showWindowOperation(.maximize, windowRect: bounds, duration: 0.5)
                }
            }

            return result
        }

        if !success {
            throw OperationError.interactionFailed(
                action: "maximize window",
                reason: "Window maximize operation failed")
        }
    }

    public func moveWindow(target: WindowTarget, to position: CGPoint) async throws {
        // Get window bounds for animation
        var windowBounds: CGRect?

        let success = try await performWindowOperation(target: target) { window in
            // Get window bounds before moving
            if let currentPosition = window.position(), let size = window.size() {
                windowBounds = CGRect(origin: currentPosition, size: size)
            }

            let result = window.moveWindow(to: position)

            // Show move animation if we have bounds
            if let bounds = windowBounds {
                // Create new bounds at target position
                let newBounds = CGRect(origin: position, size: bounds.size)
                Task {
                    _ = await self.feedbackClient.showWindowOperation(.move, windowRect: newBounds, duration: 0.5)
                }
            }

            return result
        }

        if !success {
            throw OperationError.interactionFailed(
                action: "move window",
                reason: "Window move operation failed")
        }
    }

    public func resizeWindow(target: WindowTarget, to size: CGSize) async throws {
        // Get window bounds for animation
        var windowBounds: CGRect?

        // Log the resize operation for performance debugging
        let resizeDescription = "target=\(target), size=(width: \(size.width), height: \(size.height))"
        self.logger.info("Starting resize window operation: \(resizeDescription)")
        let startTime = Date()

        let success = try await performWindowOperation(target: target) { window in
            // Get window position before resizing
            if let position = window.position() {
                windowBounds = CGRect(origin: position, size: size)
            }

            let result = window.resizeWindow(to: size)

            // Show resize animation if we have bounds
            if let bounds = windowBounds {
                Task {
                    _ = await self.feedbackClient.showWindowOperation(.resize, windowRect: bounds, duration: 0.5)
                }
            }

            return result
        }

        let elapsed = Date().timeIntervalSince(startTime)
        self.logger.info("Resize window operation completed in \(elapsed)s")

        if !success {
            throw OperationError.interactionFailed(
                action: "resize window",
                reason: "Window resize operation failed")
        }
    }

    public func setWindowBounds(target: WindowTarget, bounds: CGRect) async throws {
        let success = try await performWindowOperation(target: target) { window in
            let result = window.setWindowBounds(bounds)

            // Show bounds animation after setting
            Task {
                _ = await self.feedbackClient.showWindowOperation(.setBounds, windowRect: bounds, duration: 0.5)
            }

            return result
        }

        if !success {
            throw OperationError.interactionFailed(
                action: "set window bounds",
                reason: "Window bounds operation failed")
        }
    }

    public func focusWindow(target: WindowTarget) async throws {
        // Add logging to debug focus issues
        self.logger.info("Attempting to focus window with target: \(target)")
        self.logger.debug("WindowManagementService.focusWindow called with target: \(target)")

        // Get window bounds for animation
        var windowBounds: CGRect?

        let success = try await performWindowOperation(target: target) { window in
            // Get window bounds for focus animation
            if let position = window.position(), let size = window.size() {
                windowBounds = CGRect(origin: position, size: size)
            }

            self.logger.debug("About to call window.focusWindow()")
            let result = window.focusWindow()
            self.logger.debug("window.focusWindow() returned: \(result)")
            if !result {
                self.logger.error("focusWindow() returned false for window")
            }

            // Show focus animation if we have bounds
            if let bounds = windowBounds {
                Task {
                    _ = await self.feedbackClient.showWindowOperation(.focus, windowRect: bounds, duration: 0.5)
                }
            }

            return result
        }

        if !success {
            // Get more context about the window for better error messages
            let windowInfo = switch target {
            case .frontmost:
                "frontmost window"
            case let .application(app):
                "window for app '\(app)'"
            case let .title(title):
                "window with title containing '\(title)'"
            case let .index(app, index):
                "window at index \(index) for app '\(app)'"
            case let .applicationAndTitle(app, title):
                "window with title '\(title)' for app '\(app)'"
            case let .windowId(id):
                "window with ID \(id)"
            }

            self.logger.error("Focus window failed for: \(windowInfo)")

            let reason = [
                "Failed to focus \(windowInfo).",
                "The window may be minimized, on another Space, or the app may not be responding to focus requests.",
            ].joined(separator: " ")
            throw OperationError.interactionFailed(action: "focus window", reason: reason)
        }
    }

    public func listWindows(target: WindowTarget) async throws -> [ServiceWindowInfo] {
        switch target {
        case let .application(appIdentifier):
            return try await self.windows(for: appIdentifier)

        case let .title(titleSubstring):
            return try await self.windowsWithTitleSubstring(titleSubstring)

        case let .applicationAndTitle(appIdentifier, titleSubstring):
            return try await self.windows(for: appIdentifier)
                .filter { $0.title.localizedCaseInsensitiveContains(titleSubstring) }

        case let .index(app, index):
            let windows = try await self.windows(for: app)
            guard index >= 0, index < windows.count else {
                throw PeekabooError.invalidInput(
                    "windowIndex: Index \(index) is out of range. Available windows: 0-\(windows.count - 1)")
            }
            return [windows[index]]

        case .frontmost:
            let frontmostApp = try await applicationService.getFrontmostApplication()
            let windows = try await self.windows(for: frontmostApp.name)
            return windows.isEmpty ? [] : [windows[0]]

        case let .windowId(id):
            return try await self.windowById(id)
        }
    }

    public func getFocusedWindow() async throws -> ServiceWindowInfo? {
        let frontmostApp = try await applicationService.getFrontmostApplication()
        let windows = try await self.windows(for: frontmostApp.name)
        return windows.first
    }
}
