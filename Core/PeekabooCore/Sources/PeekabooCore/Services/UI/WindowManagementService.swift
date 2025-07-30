import Foundation
import CoreGraphics
import AXorcist
import AppKit
import os.log

/// Default implementation of window management operations using AXorcist
@MainActor
public final class WindowManagementService: WindowManagementServiceProtocol {
    
    private let applicationService: ApplicationServiceProtocol
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "WindowManagementService")
    
    // Visualizer client for visual feedback
    private let visualizerClient = VisualizationClient.shared
    
    public init(applicationService: ApplicationServiceProtocol? = nil) {
        self.applicationService = applicationService ?? ApplicationService()
        // Connect to visualizer if available
        visualizerClient.connect()
    }
    
    public func closeWindow(target: WindowTarget) async throws {
        // Get window bounds for animation
        var windowBounds: CGRect? = nil
        
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
                reason: "Window close operation failed"
            )
        }
    }
    
    public func minimizeWindow(target: WindowTarget) async throws {
        // Get window bounds for animation
        var windowBounds: CGRect? = nil
        
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
                reason: "Window minimize operation failed"
            )
        }
    }
    
    public func maximizeWindow(target: WindowTarget) async throws {
        // Get window bounds for animation
        var windowBounds: CGRect? = nil
        
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
                reason: "Window maximize operation failed"
            )
        }
    }
    
    public func moveWindow(target: WindowTarget, to position: CGPoint) async throws {
        // Get window bounds for animation
        var windowBounds: CGRect? = nil
        
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
                reason: "Window move operation failed"
            )
        }
    }
    
    public func resizeWindow(target: WindowTarget, to size: CGSize) async throws {
        // Get window bounds for animation
        var windowBounds: CGRect? = nil
        
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
        
        if !success {
            throw OperationError.interactionFailed(
                action: "resize window",
                reason: "Window resize operation failed"
            )
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
                reason: "Window bounds operation failed"
            )
        }
    }
    
    public func focusWindow(target: WindowTarget) async throws {
        // Add logging to debug focus issues
        logger.info("Attempting to focus window with target: \(target)")
        logger.debug("WindowManagementService.focusWindow called with target: \(target)")
        
        // Get window bounds for animation
        var windowBounds: CGRect? = nil
        
        let success = try await performWindowOperation(target: target) { window in
            // Get window bounds for focus animation
            if let position = window.position(), let size = window.size() {
                windowBounds = CGRect(origin: position, size: size)
            }
            
            logger.debug("About to call window.focusWindow()")
            let result = window.focusWindow()
            logger.debug("window.focusWindow() returned: \(result)")
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
            let windowInfo: String
            switch target {
            case .frontmost:
                windowInfo = "frontmost window"
            case .application(let app):
                windowInfo = "window for app '\(app)'"
            case .title(let title):
                windowInfo = "window with title containing '\(title)'"
            case .index(let app, let index):
                windowInfo = "window at index \(index) for app '\(app)'"
            case .windowId(let id):
                windowInfo = "window with ID \(id)"
            }
            
            logger.error("Focus window failed for: \(windowInfo)")
            
            throw OperationError.interactionFailed(
                action: "focus window",
                reason: "Failed to focus \(windowInfo). The window may be minimized, on another Space, or the app may not be responding to focus requests."
            )
        }
    }
    
    public func listWindows(target: WindowTarget) async throws -> [ServiceWindowInfo] {
        switch target {
        case .application(let appIdentifier):
            let output = try await applicationService.listWindows(for: appIdentifier)
            return output.data.windows
            
        case .title(let titleSubstring):
            // List all windows and filter by title
            let appsOutput = try await applicationService.listApplications()
            var matchingWindows: [ServiceWindowInfo] = []
            
            for app in appsOutput.data.applications {
                let windowsOutput = try await applicationService.listWindows(for: app.name)
                let filtered = windowsOutput.data.windows.filter { window in
                    window.title.localizedCaseInsensitiveContains(titleSubstring)
                }
                matchingWindows.append(contentsOf: filtered)
            }
            
            return matchingWindows
            
        case .index(let app, let index):
            let windowsOutput = try await applicationService.listWindows(for: app)
            let windows = windowsOutput.data.windows
            guard index >= 0 && index < windows.count else {
                throw PeekabooError.invalidInput(
                    "windowIndex: Index \(index) is out of range. Available windows: 0-\(windows.count-1)"
                )
            }
            return [windows[index]]
            
        case .frontmost:
            let frontmostApp = try await applicationService.getFrontmostApplication()
            let windowsOutput = try await applicationService.listWindows(for: frontmostApp.name)
            let windows = windowsOutput.data.windows
            return windows.isEmpty ? [] : [windows[0]]
            
        case .windowId(let id):
            // Need to search all windows to find by ID
            let appsOutput = try await applicationService.listApplications()
            
            for app in appsOutput.data.applications {
                let windowsOutput = try await applicationService.listWindows(for: app.name)
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
        let windowsOutput = try await applicationService.listWindows(for: frontmostApp.name)
        
        // The first window is typically the focused one
        return windowsOutput.data.windows.first
    }
    
    // MARK: - Private Helpers
    
    /// Performs a window operation within MainActor context
    private func performWindowOperation<T: Sendable>(
        target: WindowTarget,
        operation: @MainActor (Element) -> T
    ) async throws -> T {
        switch target {
        case .application(let appIdentifier):
            let app = try await applicationService.findApplication(identifier: appIdentifier)
            let window = try findFirstWindow(for: app)
            return operation(window)
            
        case .title(let titleSubstring):
            let appsOutput = try await applicationService.listApplications()
            let window = try findWindowByTitle(titleSubstring, in: appsOutput.data.applications)
            return operation(window)
            
        case .index(let appIdentifier, let index):
            let app = try await applicationService.findApplication(identifier: appIdentifier)
            let window = try findWindowByIndex(for: app, index: index)
            return operation(window)
            
        case .frontmost:
            let frontmostApp = try await applicationService.getFrontmostApplication()
            let window = try findFirstWindow(for: frontmostApp)
            return operation(window)
            
        case .windowId(let id):
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
        
        guard index >= 0 && index < windows.count else {
            throw PeekabooError.invalidInput(
                "windowIndex: Index \(index) is out of range. Available windows: 0-\(windows.count-1)"
            )
        }
        
        return windows[index]
    }
    
    @MainActor
    private func findWindowByTitle(_ titleSubstring: String, in apps: [ServiceApplicationInfo]) throws -> Element {
        for app in apps {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            let appElement = Element(axApp)
            
            if let windows = appElement.windows() {
                for window in windows {
                    if let title = window.title(),
                       title.localizedCaseInsensitiveContains(titleSubstring) {
                        return window
                    }
                }
            }
        }
        
        throw PeekabooError.windowNotFound()
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