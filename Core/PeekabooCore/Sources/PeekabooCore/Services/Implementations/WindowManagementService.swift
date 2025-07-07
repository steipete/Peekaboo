import Foundation
import CoreGraphics
import AXorcist
import AppKit

/// Default implementation of window management operations using AXorcist
public final class WindowManagementService: WindowManagementServiceProtocol {
    
    private let applicationService: ApplicationServiceProtocol
    
    public init(applicationService: ApplicationServiceProtocol? = nil) {
        self.applicationService = applicationService ?? ApplicationService()
    }
    
    public func closeWindow(target: WindowTarget) async throws {
        let window = try await findWindow(target: target)
        
        let success = await MainActor.run {
            window.closeWindow()
        }
        
        if !success {
            throw WindowError.operationFailed("close")
        }
    }
    
    public func minimizeWindow(target: WindowTarget) async throws {
        let window = try await findWindow(target: target)
        
        let success = await MainActor.run {
            window.minimizeWindow()
        }
        
        if !success {
            throw WindowError.operationFailed("minimize")
        }
    }
    
    public func maximizeWindow(target: WindowTarget) async throws {
        let window = try await findWindow(target: target)
        
        let success = await MainActor.run {
            window.maximizeWindow()
        }
        
        if !success {
            throw WindowError.operationFailed("maximize")
        }
    }
    
    public func moveWindow(target: WindowTarget, to position: CGPoint) async throws {
        let window = try await findWindow(target: target)
        
        let success = await MainActor.run {
            window.moveWindow(to: position)
        }
        
        if !success {
            throw WindowError.operationFailed("move")
        }
    }
    
    public func resizeWindow(target: WindowTarget, to size: CGSize) async throws {
        let window = try await findWindow(target: target)
        
        let success = await MainActor.run {
            window.resizeWindow(to: size)
        }
        
        if !success {
            throw WindowError.operationFailed("resize")
        }
    }
    
    public func setWindowBounds(target: WindowTarget, bounds: CGRect) async throws {
        let window = try await findWindow(target: target)
        
        let success = await MainActor.run {
            window.setWindowBounds(bounds)
        }
        
        if !success {
            throw WindowError.operationFailed("set bounds")
        }
    }
    
    public func focusWindow(target: WindowTarget) async throws {
        let window = try await findWindow(target: target)
        
        let success = await MainActor.run {
            window.focusWindow()
        }
        
        if !success {
            throw WindowError.operationFailed("focus")
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
                throw WindowError.invalidIndex(index, availableCount: windows.count)
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
            
            throw WindowError.windowNotFound(id: id)
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
    
    private func findWindow(target: WindowTarget) async throws -> Element {
        switch target {
        case .application(let appIdentifier):
            let app = try await applicationService.findApplication(identifier: appIdentifier)
            return try await findFirstWindow(for: app)
            
        case .title(let titleSubstring):
            return try await findWindowByTitle(titleSubstring)
            
        case .index(let appIdentifier, let index):
            let app = try await applicationService.findApplication(identifier: appIdentifier)
            return try await findWindowByIndex(for: app, index: index)
            
        case .frontmost:
            let frontmostApp = try await applicationService.getFrontmostApplication()
            return try await findFirstWindow(for: frontmostApp)
            
        case .windowId(let id):
            return try await findWindowById(id)
        }
    }
    
    @MainActor
    private func findFirstWindow(for app: ServiceApplicationInfo) async throws -> Element {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)
        
        guard let windows = appElement.windows(), !windows.isEmpty else {
            throw WindowError.noWindows(app: app.name)
        }
        
        return windows[0]
    }
    
    @MainActor
    private func findWindowByIndex(for app: ServiceApplicationInfo, index: Int) async throws -> Element {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)
        
        guard let windows = appElement.windows() else {
            throw WindowError.noWindows(app: app.name)
        }
        
        guard index >= 0 && index < windows.count else {
            throw WindowError.invalidIndex(index, availableCount: windows.count)
        }
        
        return windows[index]
    }
    
    @MainActor
    private func findWindowByTitle(_ titleSubstring: String) async throws -> Element {
        let apps = try await applicationService.listApplications()
        
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
        
        throw WindowError.windowNotFoundByTitle(titleSubstring)
    }
    
    @MainActor
    private func findWindowById(_ id: Int) async throws -> Element {
        let apps = try await applicationService.listApplications()
        
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
        
        throw WindowError.windowNotFound(id: id)
    }
}

/// Errors specific to window operations
public enum WindowError: LocalizedError {
    case operationFailed(String)
    case noWindows(app: String)
    case windowNotFound(id: Int)
    case windowNotFoundByTitle(String)
    case invalidIndex(Int, availableCount: Int)
    
    public var errorDescription: String? {
        switch self {
        case .operationFailed(let operation):
            return "Failed to \(operation) window"
        case .noWindows(let app):
            return "No windows found for application: \(app)"
        case .windowNotFound(let id):
            return "Window not found with ID: \(id)"
        case .windowNotFoundByTitle(let title):
            return "No window found with title containing: \(title)"
        case .invalidIndex(let index, let count):
            return "Invalid window index \(index). Available windows: 0-\(count-1)"
        }
    }
}