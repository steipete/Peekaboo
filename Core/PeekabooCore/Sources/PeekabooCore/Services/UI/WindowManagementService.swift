import AppKit
import AXorcist
import CoreGraphics
import Foundation
import os.log

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
    private let applicationService: ApplicationServiceProtocol
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "WindowManagementService")

    // Visualizer client for visual feedback
    private let visualizerClient = VisualizationClient.shared

    public init(applicationService: ApplicationServiceProtocol? = nil) {
        self.applicationService = applicationService ?? ApplicationService()

        // Only connect to visualizer if we're not running inside the Mac app
        // The Mac app provides the visualizer service, not consumes it
        let isMacApp = Bundle.main.bundleIdentifier == "boo.peekaboo.mac"
        if !isMacApp {
            self.logger.debug("Connecting to visualizer service (running as CLI/external tool)")
            self.visualizerClient.connect()
        } else {
            self.logger.debug("Skipping visualizer connection (running inside Mac app)")
        }
    }

    public func closeWindow(target: WindowTarget) async throws {
        // Get window bounds for animation
        var windowBounds: CGRect?

        let success = try await performWindowOperation(target: target) { window in
            // Get window bounds before closing
            if let position = window.position(), let size = window.size() {
                windowBounds = CGRect(origin: position, size: size)
            }

            let result = window.closeWindow()

            // Show close animation if we have bounds
            if let bounds = windowBounds {
                Task {
                    _ = await self.visualizerClient.showWindowOperation(.close, windowRect: bounds, duration: 0.5)
                }
            }

            return result
        }

        if !success {
            throw OperationError.interactionFailed(
                action: "close window",
                reason: "Window close operation failed")
        }
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
                    _ = await self.visualizerClient.showWindowOperation(.minimize, windowRect: bounds, duration: 0.5)
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
                    _ = await self.visualizerClient.showWindowOperation(.maximize, windowRect: bounds, duration: 0.5)
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
                    _ = await self.visualizerClient.showWindowOperation(.move, windowRect: newBounds, duration: 0.5)
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
        self.logger
            .info(
                "Starting resize window operation: target=\(target), size=(width: \(size.width), height: \(size.height))")
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
                    _ = await self.visualizerClient.showWindowOperation(.resize, windowRect: bounds, duration: 0.5)
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
                _ = await self.visualizerClient.showWindowOperation(.setBounds, windowRect: bounds, duration: 0.5)
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
                    _ = await self.visualizerClient.showWindowOperation(.focus, windowRect: bounds, duration: 0.5)
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

            throw OperationError.interactionFailed(
                action: "focus window",
                reason: "Failed to focus \(windowInfo). The window may be minimized, on another Space, or the app may not be responding to focus requests.")
        }
    }

    public func listWindows(target: WindowTarget) async throws -> [ServiceWindowInfo] {
        switch target {
        case let .application(appIdentifier):
            let output = try await applicationService.listWindows(for: appIdentifier, timeout: nil)
            return output.data.windows

        case let .title(titleSubstring):
            // List all windows and filter by title
            let appsOutput = try await applicationService.listApplications()
            var matchingWindows: [ServiceWindowInfo] = []

            for app in appsOutput.data.applications {
                let windowsOutput = try await applicationService.listWindows(for: app.name, timeout: nil)
                let filtered = windowsOutput.data.windows.filter { window in
                    window.title.localizedCaseInsensitiveContains(titleSubstring)
                }
                matchingWindows.append(contentsOf: filtered)
            }

            return matchingWindows

        case let .applicationAndTitle(appIdentifier, titleSubstring):
            // More efficient: only search windows of the specified app
            let windowsOutput = try await applicationService.listWindows(for: appIdentifier, timeout: nil)
            let filtered = windowsOutput.data.windows.filter { window in
                window.title.localizedCaseInsensitiveContains(titleSubstring)
            }
            return filtered

        case let .index(app, index):
            let windowsOutput = try await applicationService.listWindows(for: app, timeout: nil)
            let windows = windowsOutput.data.windows
            guard index >= 0, index < windows.count else {
                throw PeekabooError.invalidInput(
                    "windowIndex: Index \(index) is out of range. Available windows: 0-\(windows.count - 1)")
            }
            return [windows[index]]

        case .frontmost:
            let frontmostApp = try await applicationService.getFrontmostApplication()
            let windowsOutput = try await applicationService.listWindows(for: frontmostApp.name, timeout: nil)
            let windows = windowsOutput.data.windows
            return windows.isEmpty ? [] : [windows[0]]

        case let .windowId(id):
            // Need to search all windows to find by ID
            let appsOutput = try await applicationService.listApplications()

            for app in appsOutput.data.applications {
                let windowsOutput = try await applicationService.listWindows(for: app.name, timeout: nil)
                if let window = windowsOutput.data.windows.first(where: { $0.windowID == id }) {
                    return [window]
                }
            }

            throw PeekabooError.windowNotFound()
        }
    }

    public func getFocusedWindow() async throws -> ServiceWindowInfo? {
        // Get the frontmost application
        let frontmostApp = try await applicationService.getFrontmostApplication()

        // Get its windows
        let windowsOutput = try await applicationService.listWindows(for: frontmostApp.name, timeout: nil)

        // The first window is typically the focused one
        return windowsOutput.data.windows.first
    }

    // MARK: - Private Helpers

    /// Performs a window operation within MainActor context
    private func performWindowOperation<T: Sendable>(
        target: WindowTarget,
        operation: @MainActor (Element) -> T) async throws -> T
    {
        switch target {
        case let .application(appIdentifier):
            let app = try await applicationService.findApplication(identifier: appIdentifier)
            let window = try findFirstWindow(for: app)
            return operation(window)

        case let .title(titleSubstring):
            let appsOutput = try await applicationService.listApplications()
            let window = try findWindowByTitle(titleSubstring, in: appsOutput.data.applications)
            return operation(window)

        case let .applicationAndTitle(appIdentifier, titleSubstring):
            // More efficient: only search within the specified app
            let app = try await applicationService.findApplication(identifier: appIdentifier)
            let window = try findWindowByTitleInApp(titleSubstring, app: app)
            return operation(window)

        case let .index(appIdentifier, index):
            let app = try await applicationService.findApplication(identifier: appIdentifier)
            let window = try findWindowByIndex(for: app, index: index)
            return operation(window)

        case .frontmost:
            let frontmostApp = try await applicationService.getFrontmostApplication()
            let window = try findFirstWindow(for: frontmostApp)
            return operation(window)

        case let .windowId(id):
            let appsOutput = try await applicationService.listApplications()
            let window = try findWindowById(id, in: appsOutput.data.applications)
            return operation(window)
        }
    }

    @MainActor
    private func findFirstWindow(for app: ServiceApplicationInfo) throws -> Element {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)

        guard let windows = appElement.windows(), !windows.isEmpty else {
            throw NotFoundError.window(app: app.name)
        }

        return windows[0]
    }

    @MainActor
    private func findWindowByIndex(for app: ServiceApplicationInfo, index: Int) throws -> Element {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)

        guard let windows = appElement.windows() else {
            throw NotFoundError.window(app: app.name)
        }

        guard index >= 0, index < windows.count else {
            throw PeekabooError.invalidInput(
                "windowIndex: Index \(index) is out of range. Available windows: 0-\(windows.count - 1)")
        }

        return windows[index]
    }

    @MainActor
    private func findWindowByTitle(_ titleSubstring: String, in apps: [ServiceApplicationInfo]) throws -> Element {
        // Log the search operation
        self.logger.info("Searching for window with title containing: '\(titleSubstring)' in \(apps.count) apps")
        let startTime = Date()

        // First, try to find the window in the frontmost app (most common case)
        if let frontmostApp = apps.first(where: { app in
            // Check if this is the frontmost app by checking if it's active
            NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier
        }) {
            self.logger.debug("Checking frontmost app first: \(frontmostApp.name)")
            let axApp = AXUIElementCreateApplication(frontmostApp.processIdentifier)
            let appElement = Element(axApp)

            if let windows = appElement.windows() {
                for window in windows {
                    if let title = window.title(),
                       title.localizedCaseInsensitiveContains(titleSubstring)
                    {
                        let elapsed = Date().timeIntervalSince(startTime)
                        self.logger.info("Found window in frontmost app after \(elapsed)s")
                        return window
                    }
                }
            }
        }

        // If not found in frontmost app, search all apps
        var searchedApps = 0
        var totalWindows = 0

        for app in apps {
            searchedApps += 1

            // Skip system apps that rarely have user windows
            if app.name.hasPrefix("com.apple."),
               !["Safari", "Mail", "Notes", "Terminal", "Finder"].contains(app.name)
            {
                continue
            }

            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            let appElement = Element(axApp)

            if let windows = appElement.windows() {
                totalWindows += windows.count

                // Log progress every 5 apps to help debug performance
                if searchedApps % 5 == 0 {
                    let elapsed = Date().timeIntervalSince(startTime)
                    self.logger.debug("Searched \(searchedApps) apps, \(totalWindows) windows so far (\(elapsed)s)")
                }

                for window in windows {
                    if let title = window.title(),
                       title.localizedCaseInsensitiveContains(titleSubstring)
                    {
                        let elapsed = Date().timeIntervalSince(startTime)
                        self.logger
                            .info(
                                "Found window '\(title)' in app '\(app.name)' after searching \(searchedApps) apps and \(totalWindows) windows (\(elapsed)s)")
                        return window
                    }
                }
            }
        }

        let elapsed = Date().timeIntervalSince(startTime)
        self.logger
            .error("Window not found after searching \(searchedApps) apps and \(totalWindows) windows (\(elapsed)s)")
        throw PeekabooError.windowNotFound()
    }

    @MainActor
    private func findWindowByTitleInApp(_ titleSubstring: String, app: ServiceApplicationInfo) throws -> Element {
        self.logger.info("Searching for window with title containing: '\(titleSubstring)' in app: \(app.name)")

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)

        guard let windows = appElement.windows() else {
            throw NotFoundError.window(app: app.name)
        }

        for window in windows {
            if let title = window.title(),
               title.localizedCaseInsensitiveContains(titleSubstring)
            {
                self.logger.info("Found window '\(title)' in app '\(app.name)'")
                return window
            }
        }

        throw PeekabooError.windowNotFound(criteria: "title containing '\(titleSubstring)' in app '\(app.name)'")
    }

    @MainActor
    private func findWindowById(_ id: Int, in apps: [ServiceApplicationInfo]) throws -> Element {
        for app in apps {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            let appElement = Element(axApp)

            if let windows = appElement.windows() {
                // We don't have direct window IDs in AXorcist, so use index
                for (index, window) in windows.enumerated() {
                    if index == id {
                        return window
                    }
                }
            }
        }

        throw PeekabooError.windowNotFound()
    }
}
