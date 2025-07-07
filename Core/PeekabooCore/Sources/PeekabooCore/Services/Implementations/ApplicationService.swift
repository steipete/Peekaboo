import Foundation
import AppKit
import AXorcist

/// Default implementation of application management operations
public final class ApplicationService: ApplicationServiceProtocol {
    
    public init() {}
    
    public func listApplications() async throws -> [ServiceApplicationInfo] {
        let runningApps = NSWorkspace.shared.runningApplications
        
        return runningApps.compactMap { app in
            // Skip apps without a localized name
            guard let name = app.localizedName else { return nil }
            
            // Skip system/background apps unless they have windows
            if app.activationPolicy == .prohibited {
                return nil
            }
            
            return ServiceApplicationInfo(
                processIdentifier: app.processIdentifier,
                bundleIdentifier: app.bundleIdentifier,
                name: name,
                bundlePath: app.bundleURL?.path,
                isActive: app.isActive,
                isHidden: app.isHidden,
                windowCount: 0  // Will be updated separately
            )
        }.sorted { $0.name < $1.name }
    }
    
    public func findApplication(identifier: String) async throws -> ServiceApplicationInfo {
        let runningApps = NSWorkspace.shared.runningApplications
        
        // Try exact bundle ID match
        if let app = runningApps.first(where: { $0.bundleIdentifier == identifier }) {
            return createApplicationInfo(from: app)
        }
        
        // Try exact name match (case-insensitive)
        let lowercaseIdentifier = identifier.lowercased()
        if let app = runningApps.first(where: { 
            $0.localizedName?.lowercased() == lowercaseIdentifier 
        }) {
            return createApplicationInfo(from: app)
        }
        
        // Try fuzzy match
        let matches = runningApps.filter { app in
            guard let name = app.localizedName else { return false }
            return name.lowercased().contains(lowercaseIdentifier) ||
                   (app.bundleIdentifier?.lowercased().contains(lowercaseIdentifier) ?? false)
        }
        
        if matches.count == 1 {
            return createApplicationInfo(from: matches[0])
        } else if matches.count > 1 {
            // If multiple matches, prefer the active one
            if let activeApp = matches.first(where: { $0.isActive }) {
                return createApplicationInfo(from: activeApp)
            }
            
            // Otherwise throw ambiguous error
            let names = matches.compactMap { $0.localizedName }.joined(separator: ", ")
            throw ApplicationError.ambiguousIdentifier(identifier, candidates: names)
        }
        
        throw ApplicationError.notFound(identifier)
    }
    
    public func listWindows(for appIdentifier: String) async throws -> [ServiceWindowInfo] {
        let app = try await findApplication(identifier: appIdentifier)
        
        return await MainActor.run {
            // Get AX element for the application
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            let appElement = Element(axApp)
            
            // Get windows
            guard let axWindows = appElement.windows() else {
                return []
            }
            
            return axWindows.enumerated().compactMap { index, window in
                self.createWindowInfo(from: window, index: index)
            }
        }
    }
    
    public func getFrontmostApplication() async throws -> ServiceApplicationInfo {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            throw ApplicationError.noFrontmostApplication
        }
        
        return createApplicationInfo(from: frontmostApp)
    }
    
    public func isApplicationRunning(identifier: String) async -> Bool {
        do {
            _ = try await findApplication(identifier: identifier)
            return true
        } catch {
            return false
        }
    }
    
    public func launchApplication(identifier: String) async throws -> ServiceApplicationInfo {
        // First check if already running
        if let existingApp = try? await findApplication(identifier: identifier) {
            return existingApp
        }
        
        // Try to launch by bundle ID
        let workspace = NSWorkspace.shared
        
        // Find the app URL
        let appURL: URL
        if let url = workspace.urlForApplication(withBundleIdentifier: identifier) {
            appURL = url
        } else if let url = findApplicationByName(identifier) {
            appURL = url
        } else {
            throw ApplicationError.notInstalled(identifier)
        }
        
        // Launch the application
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        
        let runningApp = try await workspace.openApplication(at: appURL, configuration: config)
        
        // Wait a bit for the app to fully launch
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        return createApplicationInfo(from: runningApp)
    }
    
    public func activateApplication(identifier: String) async throws {
        let app = try await findApplication(identifier: identifier)
        
        guard let runningApp = NSRunningApplication(processIdentifier: app.processIdentifier) else {
            throw ApplicationError.activationFailed(identifier)
        }
        
        let activated = runningApp.activate(options: [.activateIgnoringOtherApps])
        
        if !activated {
            throw ApplicationError.activationFailed(identifier)
        }
        
        // Wait for activation to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    // MARK: - Private Helpers
    
    private func createApplicationInfo(from app: NSRunningApplication) -> ServiceApplicationInfo {
        return ServiceApplicationInfo(
            processIdentifier: app.processIdentifier,
            bundleIdentifier: app.bundleIdentifier,
            name: app.localizedName ?? "Unknown",
            bundlePath: app.bundleURL?.path,
            isActive: app.isActive,
            isHidden: app.isHidden,
            windowCount: getWindowCount(for: app)
        )
    }
    
    @MainActor
    private func createWindowInfo(from window: Element, index: Int) -> ServiceWindowInfo? {
        guard let title = window.title() else { return nil }
        
        let position = window.position() ?? .zero
        let size = window.size() ?? .zero
        let bounds = CGRect(origin: position, size: size)
        
        let isMinimized = window.isMinimized() ?? false
        let isMain = window.isMain() ?? false
        
        return ServiceWindowInfo(
            windowID: index, // We don't have a real window ID from AX
            title: title,
            bounds: bounds,
            isMinimized: isMinimized,
            isMainWindow: isMain,
            index: index
        )
    }
    
    private func getWindowCount(for app: NSRunningApplication) -> Int {
        // For now, return 0 - getting accurate window count requires MainActor
        // This will be populated when windows are actually queried
        return 0
    }
    
    private func findApplicationByName(_ name: String) -> URL? {
        let workspace = NSWorkspace.shared
        
        // Common application directories
        let searchPaths = [
            "/Applications",
            "/System/Applications",
            "/Applications/Utilities",
            "~/Applications"
        ].map { NSString(string: $0).expandingTildeInPath }
        
        let fileManager = FileManager.default
        
        for path in searchPaths {
            let searchName = name.hasSuffix(".app") ? name : "\(name).app"
            let fullPath = (path as NSString).appendingPathComponent(searchName)
            
            if fileManager.fileExists(atPath: fullPath) {
                return URL(fileURLWithPath: fullPath)
            }
        }
        
        // Try Spotlight as last resort
        return workspace.urlForApplication(withBundleIdentifier: name)
    }
}

/// Errors specific to application operations
public enum ApplicationError: LocalizedError {
    case notFound(String)
    case ambiguousIdentifier(String, candidates: String)
    case noFrontmostApplication
    case notInstalled(String)
    case activationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .notFound(let identifier):
            return "Application not found: \(identifier)"
        case .ambiguousIdentifier(let identifier, let candidates):
            return "Multiple applications match '\(identifier)': \(candidates)"
        case .noFrontmostApplication:
            return "No frontmost application found"
        case .notInstalled(let identifier):
            return "Application not installed: \(identifier)"
        case .activationFailed(let identifier):
            return "Failed to activate application: \(identifier)"
        }
    }
}