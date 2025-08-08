//
//  WindowToolFormatter.swift
//  Peekaboo
//

import Foundation
import PeekabooCore

/// Formatter for window management tools with comprehensive result formatting
class WindowToolFormatter: BaseToolFormatter {
    
    override func formatCompactSummary(arguments: [String: Any]) -> String {
        switch toolType {
        case .focusWindow:
            if let app = arguments["appName"] as? String {
                return app
            }
            return "active window"
            
        case .resizeWindow:
            var parts: [String] = []
            if let app = arguments["appName"] as? String {
                parts.append(app)
            }
            if let width = arguments["width"], let height = arguments["height"] {
                parts.append("to \(width)x\(height)")
            }
            return parts.isEmpty ? "active window" : parts.joined(separator: " ")
            
        case .listWindows:
            if let app = arguments["appName"] as? String {
                return "for \(app)"
            }
            return ""
            
        case .minimizeWindow, .maximizeWindow:
            if let app = arguments["appName"] as? String {
                return app
            }
            return "active window"
            
        case .listScreens:
            return ""
            
        default:
            return super.formatCompactSummary(arguments: arguments)
        }
    }
    
    override func formatResultSummary(result: [String: Any]) -> String {
        switch toolType {
        case .focusWindow:
            return formatFocusWindowResult(result)
        case .resizeWindow:
            return formatResizeWindowResult(result)
        case .listWindows:
            return formatListWindowsResult(result)
        case .minimizeWindow:
            return formatMinimizeWindowResult(result)
        case .maximizeWindow:
            return formatMaximizeWindowResult(result)
        case .listScreens:
            return formatListScreensResult(result)
        case .listSpaces:
            return formatListSpacesResult(result)
        case .switchSpace:
            return formatSwitchSpaceResult(result)
        case .moveWindowToSpace:
            return formatMoveWindowToSpaceResult(result)
        default:
            return super.formatResultSummary(result: result)
        }
    }
    
    // MARK: - Window Management
    
    private func formatFocusWindowResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Focused")
        
        // Window title
        if let title = ToolResultExtractor.string("windowTitle", from: result) {
            let truncated = title.count > 40
                ? String(title.prefix(40)) + "..."
                : title
            parts.append("\"\(truncated)\"")
        }
        
        // App name
        if let app = ToolResultExtractor.string("app", from: result) ?? 
                      ToolResultExtractor.string("appName", from: result) {
            parts.append("(\(app))")
        }
        
        // Window details
        var details: [String] = []
        
        if let windowId = ToolResultExtractor.int("windowId", from: result) {
            details.append("ID: \(windowId)")
        }
        
        if let bounds = ToolResultExtractor.dictionary("bounds", from: result) {
            if let width = bounds["width"] as? Int,
               let height = bounds["height"] as? Int {
                details.append("\(width)×\(height)")
            }
        }
        
        if let space = ToolResultExtractor.int("space", from: result) {
            details.append("space \(space)")
        }
        
        if let screen = ToolResultExtractor.string("screen", from: result) {
            details.append("on \(screen)")
        }
        
        if !details.isEmpty {
            parts.append("[\(details.joined(separator: ", "))]")
        }
        
        // State changes
        if let wasMinimized = ToolResultExtractor.bool("wasMinimized", from: result), wasMinimized {
            parts.append("• Restored from minimized")
        }
        
        if let wasHidden = ToolResultExtractor.bool("wasHidden", from: result), wasHidden {
            parts.append("• Unhidden")
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatResizeWindowResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Resized")
        
        // Window info
        if let app = ToolResultExtractor.string("app", from: result) {
            parts.append(app)
            
            if let title = ToolResultExtractor.string("windowTitle", from: result) {
                let truncated = title.count > 30
                    ? String(title.prefix(30)) + "..."
                    : title
                parts.append("\"\(truncated)\"")
            }
        }
        
        // Size change
        if let newBounds = ToolResultExtractor.dictionary("newBounds", from: result),
           let oldBounds = ToolResultExtractor.dictionary("oldBounds", from: result) {
            
            if let newWidth = newBounds["width"] as? Int,
               let newHeight = newBounds["height"] as? Int,
               let oldWidth = oldBounds["width"] as? Int,
               let oldHeight = oldBounds["height"] as? Int {
                
                parts.append("from \(oldWidth)×\(oldHeight) to \(newWidth)×\(newHeight)")
                
                // Calculate percentage change
                let widthChange = ((Double(newWidth) - Double(oldWidth)) / Double(oldWidth)) * 100
                let heightChange = ((Double(newHeight) - Double(oldHeight)) / Double(oldHeight)) * 100
                
                if abs(widthChange) > 5 || abs(heightChange) > 5 {
                    parts.append(String(format: "[%+.0f%% width, %+.0f%% height]", widthChange, heightChange))
                }
            }
        } else if let width = ToolResultExtractor.int("width", from: result),
                  let height = ToolResultExtractor.int("height", from: result) {
            parts.append("to \(width)×\(height)")
        }
        
        // Position change
        if let newX = ToolResultExtractor.int("x", from: result),
           let newY = ToolResultExtractor.int("y", from: result) {
            parts.append("at (\(newX), \(newY))")
        }
        
        // Constraints
        if let constrained = ToolResultExtractor.bool("constrained", from: result), constrained {
            parts.append("⚠️ Constrained to screen bounds")
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatListWindowsResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        // Window count
        if let windows: [[String: Any]] = ToolResultExtractor.array("windows", from: result) {
            let count = windows.count
            parts.append("→ \(count) window\(count == 1 ? "" : "s")")
            
            // App breakdown
            let appGroups = Dictionary(grouping: windows) { window in
                (window["app"] as? String) ?? "Unknown"
            }
            
            if appGroups.count > 1 {
                let appSummary = appGroups.map { app, wins in
                    "\(app): \(wins.count)"
                }.sorted().prefix(3).joined(separator: ", ")
                parts.append("[\(appSummary)]")
            } else if let app = appGroups.keys.first {
                parts.append("for \(app)")
            }
            
            // Window states
            let minimized = windows.filter { ($0["isMinimized"] as? Bool) == true }.count
            let hidden = windows.filter { ($0["isHidden"] as? Bool) == true }.count
            let fullscreen = windows.filter { ($0["isFullscreen"] as? Bool) == true }.count
            
            var states: [String] = []
            if minimized > 0 { states.append("\(minimized) minimized") }
            if hidden > 0 { states.append("\(hidden) hidden") }
            if fullscreen > 0 { states.append("\(fullscreen) fullscreen") }
            
            if !states.isEmpty {
                parts.append("(\(states.joined(separator: ", ")))")
            }
            
            // Top windows
            if count <= 3 {
                let titles = windows.compactMap { $0["title"] as? String }.prefix(3)
                if !titles.isEmpty {
                    let titleList = titles.map { title in
                        let truncated = title.count > 25 ? String(title.prefix(25)) + "..." : title
                        return "\"\(truncated)\""
                    }.joined(separator: ", ")
                    parts.append("• \(titleList)")
                }
            }
        } else if let count = ToolResultExtractor.int("count", from: result) {
            parts.append("→ \(count) window\(count == 1 ? "" : "s")")
        } else {
            // Fallback for legacy format
            if let data = result["data"] as? [String: Any],
               let windows = data["windows"] as? [[String: Any]] {
                let count = windows.count
                parts.append("→ \(count) window\(count == 1 ? "" : "s")")
            }
        }
        
        // Filter info
        if let app = ToolResultExtractor.string("app", from: result) ?? 
                     ToolResultExtractor.string("appName", from: result) {
            if !parts.joined(separator: " ").contains(app) {
                parts.append("for \(app)")
            }
        }
        
        if let screen = ToolResultExtractor.string("screen", from: result) {
            parts.append("on \(screen)")
        }
        
        return parts.isEmpty ? "→ listed" : parts.joined(separator: " ")
    }
    
    private func formatMinimizeWindowResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Minimized")
        
        // Window info
        if let app = ToolResultExtractor.string("app", from: result) {
            parts.append(app)
        }
        
        if let title = ToolResultExtractor.string("windowTitle", from: result) {
            let truncated = title.count > 40
                ? String(title.prefix(40)) + "..."
                : title
            parts.append("\"\(truncated)\"")
        }
        
        // Animation info
        if let animated = ToolResultExtractor.bool("animated", from: result), animated {
            parts.append("with animation")
        }
        
        // Dock position
        if let dockPosition = ToolResultExtractor.string("dockPosition", from: result) {
            parts.append("to \(dockPosition) of Dock")
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatMaximizeWindowResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Maximized")
        
        // Window info
        if let app = ToolResultExtractor.string("app", from: result) {
            parts.append(app)
        }
        
        if let title = ToolResultExtractor.string("windowTitle", from: result) {
            let truncated = title.count > 40
                ? String(title.prefix(40)) + "..."
                : title
            parts.append("\"\(truncated)\"")
        }
        
        // Size info
        if let newBounds = ToolResultExtractor.dictionary("bounds", from: result) {
            if let width = newBounds["width"] as? Int,
               let height = newBounds["height"] as? Int {
                parts.append("to \(width)×\(height)")
            }
        }
        
        // Fullscreen state
        if let fullscreen = ToolResultExtractor.bool("fullscreen", from: result), fullscreen {
            parts.append("• Entered fullscreen")
        }
        
        // Screen info
        if let screen = ToolResultExtractor.string("screen", from: result) {
            parts.append("on \(screen)")
        }
        
        return parts.joined(separator: " ")
    }
    
    // MARK: - Screen Management
    
    private func formatListScreensResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        // Screen count
        if let screens: [[String: Any]] = ToolResultExtractor.array("screens", from: result) {
            let count = screens.count
            parts.append("→ \(count) screen\(count == 1 ? "" : "s")")
            
            // Main screen
            if let mainScreen = screens.first(where: { ($0["isMain"] as? Bool) == true }) {
                if let name = mainScreen["name"] as? String {
                    parts.append("Main: \(name)")
                }
                
                if let width = mainScreen["width"] as? Int,
                   let height = mainScreen["height"] as? Int {
                    parts.append("(\(width)×\(height))")
                }
            }
            
            // External screens
            let externalCount = screens.filter { ($0["isBuiltin"] as? Bool) != true }.count
            if externalCount > 0 {
                parts.append("• \(externalCount) external")
            }
            
            // Total resolution
            if screens.count > 1 {
                let totalWidth = screens.compactMap { $0["width"] as? Int }.reduce(0, +)
                let totalHeight = screens.compactMap { $0["height"] as? Int }.max() ?? 0
                parts.append("• Total: \(totalWidth)×\(totalHeight)")
            }
        } else if let count = ToolResultExtractor.int("count", from: result) {
            parts.append("→ \(count) screen\(count == 1 ? "" : "s")")
        }
        
        return parts.isEmpty ? "→ listed" : parts.joined(separator: " ")
    }
    
    // MARK: - Space Management
    
    private func formatListSpacesResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        // Space count
        if let spaces: [[String: Any]] = ToolResultExtractor.array("spaces", from: result) {
            let count = spaces.count
            parts.append("→ \(count) space\(count == 1 ? "" : "s")")
            
            // Current space
            if let currentSpace = spaces.first(where: { ($0["isCurrent"] as? Bool) == true }) {
                if let index = currentSpace["index"] as? Int {
                    parts.append("Current: Space \(index)")
                }
                
                if let windowCount = currentSpace["windowCount"] as? Int {
                    parts.append("(\(windowCount) windows)")
                }
            }
            
            // Space types
            let fullscreenSpaces = spaces.filter { ($0["isFullscreen"] as? Bool) == true }.count
            let visibleSpaces = spaces.filter { ($0["isVisible"] as? Bool) == true }.count
            
            var details: [String] = []
            if fullscreenSpaces > 0 {
                details.append("\(fullscreenSpaces) fullscreen")
            }
            if visibleSpaces > 1 {
                details.append("\(visibleSpaces) visible")
            }
            
            if !details.isEmpty {
                parts.append("[\(details.joined(separator: ", "))]")
            }
        } else if let count = ToolResultExtractor.int("count", from: result) {
            parts.append("→ \(count) space\(count == 1 ? "" : "s")")
        }
        
        // Current space info
        if let current = ToolResultExtractor.int("currentSpace", from: result) {
            parts.append("• Currently on Space \(current)")
        }
        
        return parts.isEmpty ? "→ listed" : parts.joined(separator: " ")
    }
    
    private func formatSwitchSpaceResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Switched to")
        
        // Space info
        if let spaceIndex = ToolResultExtractor.int("spaceIndex", from: result) {
            parts.append("Space \(spaceIndex)")
        } else if let spaceName = ToolResultExtractor.string("spaceName", from: result) {
            parts.append(spaceName)
        }
        
        // Previous space
        if let previousSpace = ToolResultExtractor.int("previousSpace", from: result) {
            parts.append("(from Space \(previousSpace))")
        }
        
        // Animation
        if let animated = ToolResultExtractor.bool("animated", from: result), animated {
            parts.append("with animation")
        }
        
        // Windows on new space
        if let windowCount = ToolResultExtractor.int("windowCount", from: result) {
            parts.append("• \(windowCount) window\(windowCount == 1 ? "" : "s") here")
        }
        
        // Apps on new space
        if let apps: [String] = ToolResultExtractor.array("apps", from: result) {
            if !apps.isEmpty {
                let appList = apps.prefix(3).joined(separator: ", ")
                parts.append("• Apps: \(appList)")
            }
        }
        
        return parts.isEmpty ? "→ switched" : parts.joined(separator: " ")
    }
    
    private func formatMoveWindowToSpaceResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Moved")
        
        // Window info
        if let app = ToolResultExtractor.string("app", from: result) {
            parts.append(app)
            
            if let title = ToolResultExtractor.string("windowTitle", from: result) {
                let truncated = title.count > 30
                    ? String(title.prefix(30)) + "..."
                    : title
                parts.append("\"\(truncated)\"")
            }
        }
        
        // Space transition
        if let toSpace = ToolResultExtractor.int("toSpace", from: result) {
            parts.append("to Space \(toSpace)")
            
            if let fromSpace = ToolResultExtractor.int("fromSpace", from: result) {
                parts.append("(from Space \(fromSpace))")
            }
        }
        
        // Follow window
        if let followed = ToolResultExtractor.bool("followedWindow", from: result), followed {
            parts.append("• Switched to new space")
        }
        
        // Other windows
        if let remainingWindows = ToolResultExtractor.int("remainingWindows", from: result) {
            parts.append("• \(remainingWindows) windows remain on original space")
        }
        
        return parts.isEmpty ? "→ moved" : parts.joined(separator: " ")
    }
    
    override func formatStarting(arguments: [String: Any]) -> String {
        switch toolType {
        case .focusWindow:
            let app = arguments["appName"] as? String ?? "window"
            return "Focusing \(app)..."
            
        case .resizeWindow:
            let summary = formatCompactSummary(arguments: arguments)
            if !summary.isEmpty {
                return "Resizing \(summary)..."
            }
            return "Resizing window..."
            
        case .listWindows:
            if let app = arguments["appName"] as? String {
                return "Listing windows for \(app)..."
            }
            return "Listing all windows..."
            
        case .minimizeWindow:
            let app = arguments["appName"] as? String ?? "window"
            return "Minimizing \(app)..."
            
        case .maximizeWindow:
            let app = arguments["appName"] as? String ?? "window"
            return "Maximizing \(app)..."
            
        case .listScreens:
            return "Listing screens..."
            
        default:
            return super.formatStarting(arguments: arguments)
        }
    }
}