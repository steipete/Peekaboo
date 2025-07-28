import Foundation
import CoreGraphics
import AXorcist
import AppKit

/// Default implementation of window management operations using AXorcist
@MainActor
public final class WindowManagementService: WindowManagementServiceProtocol {
    
    private let applicationService: ApplicationServiceProtocol
    
    public init(applicationService: ApplicationServiceProtocol? = nil) {
        self.applicationService = applicationService ?? ApplicationService()
    }
    
    public func closeWindow(target: WindowTarget) async throws {
        let success = try await performWindowOperation(target: target) { window in
            window.closeWindow()
        }
        
        if !success {
            throw OperationError.interactionFailed(
                action: "close window",
                reason: "Window close operation failed"
            )
        }
    }
    
    public func minimizeWindow(target: WindowTarget) async throws {
        let success = try await performWindowOperation(target: target) { window in
            window.minimizeWindow()
        }
        
        if !success {
            throw OperationError.interactionFailed(
                action: "minimize window",
                reason: "Window minimize operation failed"
            )
        }
    }
    
    public func maximizeWindow(target: WindowTarget) async throws {
        let success = try await performWindowOperation(target: target) { window in
            window.maximizeWindow()
        }
        
        if !success {
            throw OperationError.interactionFailed(
                action: "maximize window",
                reason: "Window maximize operation failed"
            )
        }
    }
    
    public func moveWindow(target: WindowTarget, to position: CGPoint) async throws {
        let success = try await performWindowOperation(target: target) { window in
            window.moveWindow(to: position)
        }
        
        if !success {
            throw OperationError.interactionFailed(
                action: "move window",
                reason: "Window move operation failed"
            )
        }
    }
    
    public func resizeWindow(target: WindowTarget, to size: CGSize) async throws {
        let success = try await performWindowOperation(target: target) { window in
            window.resizeWindow(to: size)
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
            window.setWindowBounds(bounds)
        }
        
        if !success {
            throw OperationError.interactionFailed(
                action: "set window bounds",
                reason: "Window bounds operation failed"
            )
        }
    }
    
    public func focusWindow(target: WindowTarget) async throws {
        let success = try await performWindowOperation(target: target) { window in
            window.focusWindow()
        }
        
        if !success {
            throw OperationError.interactionFailed(
                action: "focus window",
                reason: "Window focus operation failed"
            )
        }
    }
    
    public func listWindows(target: WindowTarget) async throws -> [ServiceWindowInfo] {
        switch target {
        case .application(let appIdentifier):
            return try await applicationService.listWindows(for: appIdentifier)
            
        case .title(let titleSubstring):
            // List all windows and filter by title
            let apps = try await applicationService.listApplications()
            var matchingWindows: [ServiceWindowInfo] = []
            
            for app in apps {
                let windows = try await applicationService.listWindows(for: app.name)
                let filtered = windows.filter { window in
                    window.title.localizedCaseInsensitiveContains(titleSubstring)
                }
                matchingWindows.append(contentsOf: filtered)
            }
            
            return matchingWindows
            
        case .index(let app, let index):
            let windows = try await applicationService.listWindows(for: app)
            guard index >= 0 && index < windows.count else {
                throw PeekabooError.invalidInput(
                    "windowIndex: Index \(index) is out of range. Available windows: 0-\(windows.count-1)"
                )
            }
            return [windows[index]]
            
        case .frontmost:
            let frontmostApp = try await applicationService.getFrontmostApplication()
            let windows = try await applicationService.listWindows(for: frontmostApp.name)
            return windows.isEmpty ? [] : [windows[0]]
            
        case .windowId(let id):
            // Need to search all windows to find by ID
            let apps = try await applicationService.listApplications()
            
            for app in apps {
                let windows = try await applicationService.listWindows(for: app.name)
                if let window = windows.first(where: { $0.windowID == id }) {
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
        let windows = try await applicationService.listWindows(for: frontmostApp.name)
        
        // The first window is typically the focused one
        return windows.first
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
            return try await MainActor.run {
                let window = try findFirstWindow(for: app)
                return operation(window)
            }
            
        case .title(let titleSubstring):
            let apps = try await applicationService.listApplications()
            return try await MainActor.run {
                let window = try findWindowByTitle(titleSubstring, in: apps)
                return operation(window)
            }
            
        case .index(let appIdentifier, let index):
            let app = try await applicationService.findApplication(identifier: appIdentifier)
            return try await MainActor.run {
                let window = try findWindowByIndex(for: app, index: index)
                return operation(window)
            }
            
        case .frontmost:
            let frontmostApp = try await applicationService.getFrontmostApplication()
            return try await MainActor.run {
                let window = try findFirstWindow(for: frontmostApp)
                return operation(window)
            }
            
        case .windowId(let id):
            let apps = try await applicationService.listApplications()
            return try await MainActor.run {
                let window = try findWindowById(id, in: apps)
                return operation(window)
            }
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