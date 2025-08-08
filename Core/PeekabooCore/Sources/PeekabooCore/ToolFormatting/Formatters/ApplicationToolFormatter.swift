//
//  ApplicationToolFormatter.swift
//  PeekabooCore
//

import Foundation

/// Formatter for application tools with comprehensive result formatting
public class ApplicationToolFormatter: BaseToolFormatter {
    
    public override func formatResultSummary(result: [String: Any]) -> String {
        switch toolType {
        case .listApps:
            return formatListAppsResult(result)
        case .launchApp:
            return formatLaunchAppResult(result)
        case .focusWindow:
            return formatFocusWindowResult(result)
        case .listWindows:
            return formatListWindowsResult(result)
        case .resizeWindow:
            return formatResizeWindowResult(result)
        default:
            return super.formatResultSummary(result: result)
        }
    }
    
    private func formatListAppsResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        // App count
        var appCount = 0
        if let count = ToolResultExtractor.int("count", from: result) {
            appCount = count
        } else if let apps: [[String: Any]] = ToolResultExtractor.array("apps", from: result) {
            appCount = apps.count
        }
        
        parts.append("→ \(appCount) apps running")
        
        // Categorize apps
        if let apps: [[String: Any]] = ToolResultExtractor.array("apps", from: result) {
            var categories: [String: Int] = [:]
            var activeCount = 0
            var hiddenCount = 0
            var backgroundCount = 0
            
            for app in apps {
                // Count by category
                if let category = app["category"] as? String {
                    categories[category, default: 0] += 1
                }
                
                // Count by state
                if let isActive = app["isActive"] as? Bool, isActive {
                    activeCount += 1
                }
                if let isHidden = app["isHidden"] as? Bool, isHidden {
                    hiddenCount += 1
                }
                if let isBackground = app["isBackground"] as? Bool, isBackground {
                    backgroundCount += 1
                }
            }
            
            // Add state summary
            var states: [String] = []
            if activeCount > 0 {
                states.append("\(activeCount) active")
            }
            if hiddenCount > 0 {
                states.append("\(hiddenCount) hidden")
            }
            if backgroundCount > 0 {
                states.append("\(backgroundCount) background")
            }
            
            if !states.isEmpty {
                parts.append("[\(states.joined(separator: ", "))]")
            }
            
            // Add top categories
            if !categories.isEmpty {
                let topCategories = categories.sorted { $0.value > $1.value }.prefix(3)
                let categoryList = topCategories.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
                parts.append("Categories: \(categoryList)")
            }
            
            // Memory usage summary
            let totalMemory = apps.compactMap({ $0["memoryUsage"] as? Int }).reduce(0, +)
            if totalMemory > 0 {
                let memoryStr = formatMemorySize(totalMemory)
                parts.append("Total memory: \(memoryStr)")
            }
        }
        
        return parts.joined(separator: " • ")
    }
    
    private func formatLaunchAppResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        // App name
        if let app = ToolResultExtractor.string("app", from: result) {
            parts.append("→ Launched \(app)")
        } else if let appName = ToolResultExtractor.string("appName", from: result) {
            parts.append("→ Launched \(appName)")
        } else {
            parts.append("→ Application launched")
        }
        
        // Process info
        var details: [String] = []
        
        if let pid = ToolResultExtractor.int("pid", from: result) {
            details.append("PID: \(pid)")
        }
        
        if let bundleId = ToolResultExtractor.string("bundleIdentifier", from: result) {
            details.append(bundleId)
        }
        
        // Launch time
        if let launchTime = ToolResultExtractor.double("launchTime", from: result) {
            details.append(String(format: "%.1fs", launchTime))
        }
        
        // Window info
        if let windowCount = ToolResultExtractor.int("windowCount", from: result) {
            details.append("\(windowCount) window\(windowCount == 1 ? "" : "s")")
        }
        
        if !details.isEmpty {
            parts.append("[\(details.joined(separator: ", "))]")
        }
        
        // Launch method
        if let method = ToolResultExtractor.string("launchMethod", from: result) {
            parts.append("via \(method)")
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatFocusWindowResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        // App and window
        if let app = ToolResultExtractor.string("app", from: result) {
            parts.append("→ Focused \(app)")
            
            if let windowTitle = ToolResultExtractor.string("windowTitle", from: result),
               !windowTitle.isEmpty {
                let truncated = windowTitle.count > 40 
                    ? String(windowTitle.prefix(40)) + "..."
                    : windowTitle
                parts.append("\"\(truncated)\"")
            }
        } else {
            parts.append("→ Window focused")
        }
        
        // Window details
        var details: [String] = []
        
        if let windowIndex = ToolResultExtractor.int("windowIndex", from: result) {
            details.append("Window #\(windowIndex)")
        }
        
        if let previousApp = ToolResultExtractor.string("previousApp", from: result) {
            details.append("from \(previousApp)")
        }
        
        // Focus method
        if let method = ToolResultExtractor.string("focusMethod", from: result) {
            details.append("via \(method)")
        }
        
        if !details.isEmpty {
            parts.append("[\(details.joined(separator: ", "))]")
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatListWindowsResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        // Window count
        var windowCount = 0
        if let count = ToolResultExtractor.int("count", from: result) {
            windowCount = count
        } else if let windows: [[String: Any]] = ToolResultExtractor.array("windows", from: result) {
            windowCount = windows.count
        }
        
        // App context
        if let app = ToolResultExtractor.string("app", from: result) {
            parts.append("→ \(windowCount) window\(windowCount == 1 ? "" : "s") for \(app)")
        } else {
            parts.append("→ \(windowCount) window\(windowCount == 1 ? "" : "s")")
        }
        
        // Window details
        if let windows: [[String: Any]] = ToolResultExtractor.array("windows", from: result) {
            var visibleCount = 0
            var minimizedCount = 0
            var fullscreenCount = 0
            
            for window in windows {
                if let isVisible = window["isVisible"] as? Bool, isVisible {
                    visibleCount += 1
                }
                if let isMinimized = window["isMinimized"] as? Bool, isMinimized {
                    minimizedCount += 1
                }
                if let isFullscreen = window["isFullscreen"] as? Bool, isFullscreen {
                    fullscreenCount += 1
                }
            }
            
            var states: [String] = []
            if visibleCount > 0 {
                states.append("\(visibleCount) visible")
            }
            if minimizedCount > 0 {
                states.append("\(minimizedCount) minimized")
            }
            if fullscreenCount > 0 {
                states.append("\(fullscreenCount) fullscreen")
            }
            
            if !states.isEmpty {
                parts.append("[\(states.joined(separator: ", "))]")
            }
            
            // List window titles if few
            if windowCount <= 3 {
                let titles = windows.compactMap { window in
                    (window["title"] as? String)?.isEmpty == false ? window["title"] as? String : nil
                }.prefix(3)
                
                if !titles.isEmpty {
                    let titleList = titles.map { title in
                        let truncated = title.count > 30 ? String(title.prefix(30)) + "..." : title
                        return "\"\(truncated)\""
                    }.joined(separator: ", ")
                    parts.append(titleList)
                }
            }
        }
        
        return parts.joined(separator: " ")
    }
    
    private func formatResizeWindowResult(_ result: [String: Any]) -> String {
        var parts: [String] = []
        
        parts.append("→ Window resized")
        
        // New size
        if let newSize = ToolResultExtractor.dictionary("newSize", from: result) {
            if let width = newSize["width"] as? Int,
               let height = newSize["height"] as? Int {
                parts.append("to \(width)×\(height)")
            }
        }
        
        // Old size for comparison
        if let oldSize = ToolResultExtractor.dictionary("oldSize", from: result) {
            if let width = oldSize["width"] as? Int,
               let height = oldSize["height"] as? Int {
                parts.append("(was \(width)×\(height))")
            }
        }
        
        // Position if changed
        if let newPosition = ToolResultExtractor.dictionary("newPosition", from: result) {
            if let x = newPosition["x"] as? Int,
               let y = newPosition["y"] as? Int {
                parts.append("at (\(x), \(y))")
            }
        }
        
        // Resize action
        if let action = ToolResultExtractor.string("action", from: result) {
            parts.append("[\(action)]")
        }
        
        return parts.joined(separator: " ")
    }
    
    // MARK: - Helper Methods
    
    private func formatMemorySize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = bytes < 1024 * 1024 ? .useKB :
                                bytes < 1024 * 1024 * 1024 ? .useMB : .useGB
        return formatter.string(fromByteCount: Int64(bytes))
    }
}