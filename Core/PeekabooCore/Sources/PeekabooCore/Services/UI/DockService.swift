import Foundation
import AppKit
@preconcurrency import AXorcist
import ApplicationServices
import CoreGraphics

/// Dock-specific errors
public enum DockError: Error {
    case dockNotFound
    case dockListNotFound
    case itemNotFound(String)
    case menuItemNotFound(String)
    case positionNotFound
    case launchFailed(String)
    case scriptError(String)
}

/// Default implementation of Dock interaction operations using AXorcist
@MainActor
public final class DockService: DockServiceProtocol {
    
    public init() {}
    
    public func listDockItems(includeAll: Bool = false) async throws -> [DockItem] {
        // Find Dock application
        guard let dock = findDockApplication() else {
            throw PeekabooError.operationError(message: "Dock application not found or not running.")
        }
        
        // Get Dock items list
        guard let dockList = dock.children()?.first(where: { $0.role() == "AXList" }) else {
            throw PeekabooError.operationError(message: "Dock item list not found.")
        }
        
        let dockElements = dockList.children() ?? []
        var items: [DockItem] = []
            
            for (index, element) in dockElements.enumerated() {
                let role = element.role() ?? ""
                let title = element.title() ?? ""
                let subrole = element.subrole() ?? ""
                
                // Determine item type
                let itemType: DockItemType
                if role == "AXSeparator" || subrole == "AXSeparator" {
                    itemType = .separator
                    // Skip separators unless includeAll
                    if !includeAll {
                        continue
                    }
                } else if subrole == "AXApplicationDockItem" {
                    itemType = .application
                } else if subrole == "AXFolderDockItem" {
                    itemType = .folder
                } else if subrole == "AXFileDockItem" {
                    itemType = .file
                } else if subrole == "AXURLDockItem" {
                    itemType = .url
                } else if subrole == "AXMinimizedWindowDockItem" {
                    itemType = .minimizedWindow
                } else if title.lowercased() == "trash" || title.lowercased() == "bin" {
                    itemType = .trash
                } else {
                    itemType = .unknown
                }
                
                // Get position and size
                let position = element.position()
                let size = element.size()
                
                // Check if running (for applications)
                var isRunning: Bool? = nil
                if itemType == .application {
                    isRunning = element.attribute(Attribute<Bool>("AXIsApplicationRunning"))
                }
                
                // Try to get bundle identifier for applications
                var bundleIdentifier: String? = nil
                if itemType == .application, !title.isEmpty {
                    bundleIdentifier = findBundleIdentifier(for: title)
                }
                
                let item = DockItem(
                    index: index,
                    title: title,
                    itemType: itemType,
                    isRunning: isRunning,
                    bundleIdentifier: bundleIdentifier,
                    position: position,
                    size: size
                )
                
                items.append(item)
            }
            
        return items
    }
    
    public func launchFromDock(appName: String) async throws {
        // Find the Dock item
        let dockElement = try findDockElement(appName: appName)
        
        // Click the item to launch
        do {
            try dockElement.performAction(.press)
        } catch {
            throw PeekabooError.operationError(message: "Failed to launch '\(appName)' from Dock.")
        }
        
        // Wait a bit for the launch to initiate
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
    }
    
    public func rightClickDockItem(appName: String, menuItem: String?) async throws {
        // Find the Dock item and get position
        let element = try findDockElement(appName: appName)
        
        // Get item position and size
        guard let position = element.position(),
              let size = element.size() else {
            throw PeekabooError.operationError(message: "Could not determine Dock item position for '\(appName)'.")
        }
        
        let center = CGPoint(
            x: position.x + size.width / 2,
            y: position.y + size.height / 2
        )
        
        let dockElement = element
        
        // Perform right-click
        let rightMouseDown = CGEvent(
            mouseEventSource: nil,
            mouseType: .rightMouseDown,
            mouseCursorPosition: center,
            mouseButton: .right
        )
        
        let rightMouseUp = CGEvent(
            mouseEventSource: nil,
            mouseType: .rightMouseUp,
            mouseCursorPosition: center,
            mouseButton: .right
        )
        
        rightMouseDown?.post(tap: .cghidEventTap)
        usleep(50000) // 50ms
        rightMouseUp?.post(tap: .cghidEventTap)
        
        // If menu item specified, wait for menu and click it
        if let targetMenuItem = menuItem {
            // Wait for context menu to appear
            try await Task.sleep(nanoseconds: 300_000_000) // 300ms
            
            // Find and click the menu item
            // Find the menu - it might be a child of the dock item or a system-wide menu
            var menu: Element? = nil
            
            // First check if menu is a child of the dock item
            if let childMenu = dockElement.children()?.first(where: { $0.role() == "AXMenu" }) {
                menu = childMenu
            } else {
                // Look for system-wide menus that might have appeared
                let systemWide = Element.systemWide()
                if let systemMenus = systemWide.children()?.filter({ $0.role() == "AXMenu" }),
                   let contextMenu = systemMenus.first {
                    menu = contextMenu
                }
            }
            
            if let foundMenu = menu {
                let menuItems = foundMenu.children() ?? []
                guard let targetItem = menuItems.first(where: { item in
                    item.title() == targetMenuItem ||
                    item.title()?.contains(targetMenuItem) == true
                }) else {
                    throw PeekabooError.menuNotFound("\(targetMenuItem)")
                }
                
                try targetItem.performAction(.press)
            } else {
                // If we can't find the menu, throw an error
                throw PeekabooError.menuNotFound("\(appName)")
            }
        }
    }
    
    public func hideDock() async throws {
        // Use AppleScript to set Dock auto-hide preference
        let script = "tell application \"System Events\" to set autohide of dock preferences to true"
        _ = try await runAppleScript(script)
    }
    
    public func showDock() async throws {
        // Use AppleScript to disable Dock auto-hide preference
        let script = "tell application \"System Events\" to set autohide of dock preferences to false"
        _ = try await runAppleScript(script)
    }
    
    public func isDockAutoHidden() async -> Bool {
        // Check Dock auto-hide preference using AppleScript
        let script = "tell application \"System Events\" to get autohide of dock preferences"
        
        do {
            let result = try await runAppleScript(script, captureOutput: true)
            return result.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        } catch {
            // Default to false if we can't determine the state
            return false
        }
    }
    
    public func findDockItem(name: String) async throws -> DockItem {
        let items = try await listDockItems(includeAll: false)
        
        // Try exact match first
        if let exactMatch = items.first(where: { $0.title == name }) {
            return exactMatch
        }
        
        // Try case-insensitive match
        let lowercaseName = name.lowercased()
        if let caseMatch = items.first(where: { $0.title.lowercased() == lowercaseName }) {
            return caseMatch
        }
        
        // Try partial match
        let partialMatches = items.filter { item in
            item.title.lowercased().contains(lowercaseName)
        }
        
        if partialMatches.count == 1 {
            return partialMatches[0]
        } else if partialMatches.count > 1 {
            // Prefer running applications in case of multiple matches
            if let runningMatch = partialMatches.first(where: { $0.isRunning == true }) {
                return runningMatch
            }
            // Otherwise return the first match
            return partialMatches[0]
        }
        
        throw PeekabooError.elementNotFound("\(name)")
    }
    
    // MARK: - Private Helpers
    
    @MainActor
    private func findDockApplication() -> Element? {
        let workspace = NSWorkspace.shared
        guard let dockApp = workspace.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.dock"
        }) else {
            return nil
        }
        
        return Element(AXUIElementCreateApplication(dockApp.processIdentifier))
    }
    
    @MainActor
    private func findDockElement(appName: String) throws -> Element {
        guard let dock = findDockApplication() else {
            throw DockError.dockNotFound
        }
        
        guard let dockList = dock.children()?.first(where: { $0.role() == "AXList" }) else {
            throw DockError.dockListNotFound
        }
        
        let dockItems = dockList.children() ?? []
        
        // Try exact match first
        if let exactMatch = dockItems.first(where: { $0.title() == appName }) {
            return exactMatch
        }
        
        // Try case-insensitive partial match
        let lowercaseAppName = appName.lowercased()
        if let match = dockItems.first(where: { item in
            guard let title = item.title() else { return false }
            return title.lowercased() == lowercaseAppName ||
                   title.lowercased().contains(lowercaseAppName)
        }) {
            return match
        }
        
        throw DockError.itemNotFound(appName)
    }
    
    private func findBundleIdentifier(for appName: String) -> String? {
        // Try to find the bundle identifier for a given app name
        let workspace = NSWorkspace.shared
        
        // Check running applications first
        if let runningApp = workspace.runningApplications.first(where: {
            $0.localizedName == appName || $0.localizedName?.contains(appName) == true
        }) {
            return runningApp.bundleIdentifier
        }
        
        // Try to find in common application directories
        let searchPaths = [
            "/Applications",
            "/System/Applications",
            "/Applications/Utilities",
            "~/Applications"
        ].map { NSString(string: $0).expandingTildeInPath }
        
        let fileManager = FileManager.default
        
        for path in searchPaths {
            let searchName = appName.hasSuffix(".app") ? appName : "\(appName).app"
            let fullPath = (path as NSString).appendingPathComponent(searchName)
            
            if fileManager.fileExists(atPath: fullPath) {
                if let bundle = Bundle(path: fullPath) {
                    return bundle.bundleIdentifier
                }
            }
        }
        
        return nil
    }
    
    private func runAppleScript(_ script: String, captureOutput: Bool = false) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", script]
                
                let pipe = Pipe()
                if captureOutput {
                    process.standardOutput = pipe
                }
                process.standardError = pipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    if process.terminationStatus != 0 {
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        let error = String(data: data, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: PeekabooError.operationError(message: "AppleScript execution failed: \(error)"))
                        return
                    } else if captureOutput {
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        let output = String(data: data, encoding: .utf8) ?? ""
                        continuation.resume(returning: output)
                        return
                    } else {
                        continuation.resume(returning: "")
                        return
                    }
                } catch {
                    continuation.resume(throwing: error)
                    return
                }
            }
        }
    }
}