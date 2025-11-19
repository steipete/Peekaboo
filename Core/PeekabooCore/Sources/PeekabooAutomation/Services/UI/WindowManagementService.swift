import AppKit
import AXorcist
import CoreGraphics
import Foundation
import os.log
import PeekabooFoundation
import PeekabooVisualizer

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
    private let applicationService: any ApplicationServiceProtocol
    private let windowIdentityService = WindowIdentityService()
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "WindowManagementService")

    // Visualizer client for visual feedback
    private let visualizerClient = VisualizationClient.shared

    public init(applicationService: (any ApplicationServiceProtocol)? = nil) {
        self.applicationService = applicationService ?? ApplicationService()

        // Only connect to visualizer if we're not running inside the Mac app
        // The Mac app provides the visualizer service, not consumes it
        let isMacApp = Bundle.main.bundleIdentifier?.hasPrefix("boo.peekaboo.mac") == true
        if !isMacApp {
            self.logger.debug("Connecting to visualizer service (running as CLI/external tool)")
            self.visualizerClient.connect()
        } else {
            self.logger.debug("Skipping visualizer connection (running inside Mac app)")
        }
    }
}

@MainActor
extension WindowManagementService {
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

    // MARK: - Private Helpers

    /// Performs a window operation within MainActor context
    @MainActor
    private func performWindowOperation<T: Sendable>(
        target: WindowTarget,
        operation: @MainActor (Element) -> T) async throws -> T
    {
        let window = try await self.element(for: target)
        return operation(window)
    }

    @MainActor
    private func findFirstWindow(for app: ServiceApplicationInfo) throws -> Element {
        guard let runningApp = NSRunningApplication(processIdentifier: app.processIdentifier) else {
            throw NotFoundError.application(app.name)
        }
        let appElement = AXApp(runningApp).element

        guard let windows = appElement.windows(), !windows.isEmpty else {
            throw NotFoundError.window(app: app.name)
        }

        if let renderable = self.firstRenderableWindow(from: windows, appName: app.name) {
            return renderable
        }

        self.logger.debug("Falling back to first AX window for \(app.name); no renderable window detected")
        return windows[0]
    }

    @MainActor
    private func findWindowByIndex(for app: ServiceApplicationInfo, index: Int) throws -> Element {
        guard let runningApp = NSRunningApplication(processIdentifier: app.processIdentifier) else {
            throw NotFoundError.application(app.name)
        }
        let appElement = AXApp(runningApp).element

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
    private func firstRenderableWindow(from windows: [Element], appName: String) -> Element? {
        let minimumDimension: CGFloat = 50

        for (idx, window) in windows.indexed() {
            if window.isMinimized() == true {
                self.logger.debug("Skipping minimized window idx \(idx) for \(appName)")
                continue
            }

            guard
                let size = window.size(),
                size.width >= minimumDimension,
                size.height >= minimumDimension,
                let position = window.position()
            else {
                self.logger.debug("Skipping tiny window idx \(idx) for \(appName)")
                continue
            }

            let bounds = CGRect(origin: position, size: size)
            guard bounds.width >= minimumDimension, bounds.height >= minimumDimension else {
                self.logger.debug("Skipping non-renderable window idx \(idx) for \(appName)")
                continue
            }

            self.logger.debug(
                "Selected renderable window idx \(idx) for \(appName) with bounds \(String(describing: bounds))")
            return window
        }

        return nil
    }

    @MainActor
    private func findWindowByTitle(_ titleSubstring: String, in apps: [ServiceApplicationInfo]) throws -> Element {
        // Log the search operation
        self.logger.info("Searching for window with title containing: '\(titleSubstring)' in \(apps.count) apps")
        let startTime = Date()

        if let frontmostWindow = self.findWindowInFrontmostApp(
            titleSubstring: titleSubstring,
            apps: apps,
            startTime: startTime)
        {
            return frontmostWindow
        }

        return try self.searchAllApplications(
            titleSubstring: titleSubstring,
            apps: apps,
            startTime: startTime)
    }

    @MainActor
    private func findWindowByTitleInApp(_ titleSubstring: String, app: ServiceApplicationInfo) throws -> Element {
        self.logger.info("Searching for window with title containing: '\(titleSubstring)' in app: \(app.name)")

        guard let runningApp = NSRunningApplication(processIdentifier: app.processIdentifier) else {
            throw NotFoundError.application(app.name)
        }
        let appElement = AXApp(runningApp).element

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
            guard let runningApp = NSRunningApplication(processIdentifier: app.processIdentifier) else { continue }
            let appElement = AXApp(runningApp).element

            guard let windows = appElement.windows() else { continue }
            for window in windows {
                if let windowID = self.windowIdentityService.getWindowID(from: window),
                   Int(windowID) == id
                {
                    self.logger.debug("Matched window id \(id) in app \(app.name)")
                    return window
                }
            }
        }

        throw PeekabooError.windowNotFound(criteria: "windowId \(id)")
    }

    // MARK: - Window Search Helpers

    @MainActor
    private func findWindowInFrontmostApp(
        titleSubstring: String,
        apps: [ServiceApplicationInfo],
        startTime: Date) -> Element?
    {
        guard let frontmostApp = apps.first(where: { app in
            NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier
        }) else {
            return nil
        }

        self.logger.debug("Checking frontmost app first: \(frontmostApp.name)")
        guard let runningApp = NSRunningApplication(processIdentifier: frontmostApp.processIdentifier) else { return nil }
        let appElement = AXApp(runningApp).element

        guard let windows = appElement.windows() else { return nil }
        for window in windows where window.title()?.localizedCaseInsensitiveContains(titleSubstring) == true {
            let elapsed = Date().timeIntervalSince(startTime)
            self.logger.info("Found window in frontmost app after \(elapsed)s")
            return window
        }

        return nil
    }

    @MainActor
    private func searchAllApplications(
        titleSubstring: String,
        apps: [ServiceApplicationInfo],
        startTime: Date) throws -> Element
    {
        var searchedApps = 0
        var totalWindows = 0

        for app in apps {
            searchedApps += 1

            if self.shouldSkipSystemApp(app) {
                continue
            }

            guard let runningApp = NSRunningApplication(processIdentifier: app.processIdentifier) else { continue }
            let appElement = AXApp(runningApp).element

            guard let windows = appElement.windows() else { continue }
            totalWindows += windows.count

            if searchedApps % 5 == 0 {
                let elapsed = Date().timeIntervalSince(startTime)
                self.logger.debug("Searched \(searchedApps) apps, \(totalWindows) windows so far (\(elapsed)s)")
            }

            let context = WindowSearchContext(
                appName: app.name,
                searchedApps: searchedApps,
                totalWindows: totalWindows,
                startTime: startTime)

            if let match = self.windowMatchingTitle(titleSubstring, in: windows, context: context) {
                return match
            }
        }

        let elapsed = Date().timeIntervalSince(startTime)
        self.logger
            .error("Window not found after searching \(searchedApps) apps and \(totalWindows) windows (\(elapsed)s)")
        throw PeekabooError.windowNotFound()
    }

    private func element(for target: WindowTarget) async throws -> Element {
        switch target {
        case let .application(appIdentifier):
            let app = try await applicationService.findApplication(identifier: appIdentifier)
            return try self.findFirstWindow(for: app)
        case let .title(titleSubstring):
            let appsOutput = try await applicationService.listApplications()
            return try self.findWindowByTitle(titleSubstring, in: appsOutput.data.applications)
        case let .applicationAndTitle(appIdentifier, titleSubstring):
            let app = try await applicationService.findApplication(identifier: appIdentifier)
            return try self.findWindowByTitleInApp(titleSubstring, app: app)
        case let .index(appIdentifier, index):
            let app = try await applicationService.findApplication(identifier: appIdentifier)
            return try self.findWindowByIndex(for: app, index: index)
        case .frontmost:
            let frontmostApp = try await applicationService.getFrontmostApplication()
            return try self.findFirstWindow(for: frontmostApp)
        case let .windowId(id):
            let appsOutput = try await applicationService.listApplications()
            return try self.findWindowById(id, in: appsOutput.data.applications)
        }
    }

    @MainActor
    private func windows(for appIdentifier: String) async throws -> [ServiceWindowInfo] {
        let output = try await applicationService.listWindows(for: appIdentifier, timeout: nil)
        return output.data.windows
    }

    @MainActor
    private func windowsWithTitleSubstring(_ substring: String) async throws -> [ServiceWindowInfo] {
        let appsOutput = try await applicationService.listApplications()
        var matches: [ServiceWindowInfo] = []

        for app in appsOutput.data.applications {
            let windows = try await self.windows(for: app.name)
            matches.append(contentsOf: windows.filter {
                $0.title.localizedCaseInsensitiveContains(substring)
            })
        }
        return matches
    }

    @MainActor
    private func windowById(_ id: Int) async throws -> [ServiceWindowInfo] {
        let appsOutput = try await applicationService.listApplications()
        for app in appsOutput.data.applications {
            let windows = try await self.windows(for: app.name)
            if let window = windows.first(where: { $0.windowID == id }) {
                return [window]
            }
        }
        throw PeekabooError.windowNotFound()
    }

    private func shouldSkipSystemApp(_ app: ServiceApplicationInfo) -> Bool {
        app.name.hasPrefix("com.apple.") &&
            !["Safari", "Mail", "Notes", "Terminal", "Finder"].contains(app.name)
    }

    @MainActor
    private func windowMatchingTitle(
        _ titleSubstring: String,
        in windows: [Element],
        context: WindowSearchContext) -> Element?
    {
        for window in windows where window.title()?.localizedCaseInsensitiveContains(titleSubstring) == true {
            let elapsed = Date().timeIntervalSince(context.startTime)
            let message = self.buildWindowFoundMessage(
                windowTitle: window.title() ?? "",
                context: context,
                elapsed: elapsed)
            self.logger.info("\(message, privacy: .public)")
            return window
        }
        return nil
    }

    private func buildWindowFoundMessage(
        windowTitle: String,
        context: WindowSearchContext,
        elapsed: TimeInterval) -> String
    {
        [
            "Found window '\(windowTitle)' in app '\(context.appName)'",
            "after searching \(context.searchedApps) apps and \(context.totalWindows) windows (\(elapsed)s)",
        ].joined(separator: " ")
    }
}

private struct WindowSearchContext {
    let appName: String
    let searchedApps: Int
    let totalWindows: Int
    let startTime: Date
}
