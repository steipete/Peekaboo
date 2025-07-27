import Foundation
import CoreGraphics
import AppKit
import AXorcist

// MARK: - Window Management Tools

/// Window management tools for listing, focusing, and manipulating windows
@available(macOS 14.0, *)
extension PeekabooAgentService {
    
    /// Create the list windows tool
    func createListWindowsTool() -> Tool<PeekabooServices> {
        createTool(
            name: "list_windows",
            description: "List all visible windows across all applications",
            parameters: .object(
                properties: [
                    "app": ParameterSchema.string(description: "Optional: Filter windows by application name")
                ],
                required: []
            ),
            handler: { params, context in
                let appFilter = params.string("app", default: nil)
                
                // Get all windows from all applications
                let apps = try await context.applications.listApplications()
                var windows: [ServiceWindowInfo] = []
                for app in apps {
                    let appWindows = try await context.windows.listWindows(target: .application(app.name))
                    windows.append(contentsOf: appWindows)
                }
                
                // Apply app filter if specified
                if let appFilter = appFilter {
                    // Filter by getting windows from specific app only
                    windows = []
                    if let targetApp = apps.first(where: { $0.name.lowercased().contains(appFilter.lowercased()) }) {
                        let appWindows = try await context.windows.listWindows(target: .application(targetApp.name))
                        windows = appWindows
                    }
                }
                
                if windows.isEmpty {
                    let message = if let appFilter = appFilter {
                        "No windows found for application '\(appFilter)'"
                    } else {
                        "No windows found"
                    }
                    return .success(message)
                }
                
                // Since we don't have applicationName on ServiceWindowInfo, we'll display all windows
                // without grouping by application
                
                var output = "Found \(windows.count) window(s):\n\n"
                
                for window in windows {
                    output += "  • \(window.title.isEmpty ? "Untitled" : window.title)"
                    output += " [ID: \(window.windowID)]"
                    if window.isMinimized {
                        output += " (minimized)"
                    }
                    output += "\n"
                }
                
                return .success(
                    output.trimmingCharacters(in: .whitespacesAndNewlines),
                    metadata: ["count": String(windows.count)]
                )
            }
        )
    }
    
    /// Create the focus window tool
    func createFocusWindowTool() -> Tool<PeekabooServices> {
        createTool(
            name: "focus_window",
            description: "Bring a window to the front and give it focus",
            parameters: .object(
                properties: [
                    "title": ParameterSchema.string(description: "Window title to search for (partial match supported)"),
                    "app": ParameterSchema.string(description: "Application name"),
                    "window_id": ParameterSchema.integer(description: "Specific window ID")
                ],
                required: []
            ),
            handler: { params, context in
                let title = params.string("title", default: nil)
                let appName = params.string("app", default: nil)
                let windowId = params.int("window_id", default: nil)
                
                // Require at least one parameter
                guard title != nil || appName != nil || windowId != nil else {
                    throw PeekabooError.invalidInput("At least one of 'title', 'app', or 'window_id' must be provided")
                }
                
                // First ensure the app is running and not hidden
                if let appName = appName {
                    // Get running applications
                    let apps = try await context.applications.listApplications()
                    if let app = apps.first(where: { $0.name.lowercased() == appName.lowercased() }) {
                        // Activate the application first
                        try await context.applications.activateApplication(identifier: app.bundleIdentifier ?? app.name)
                        
                        // Give it a moment to activate
                        try await Task.sleep(nanoseconds: TimeInterval.mediumDelay.nanoseconds)
                    }
                }
                
                // Get all windows from all applications
                let apps = try await context.applications.listApplications()
                var windows: [ServiceWindowInfo] = []
                for app in apps {
                    let appWindows = try await context.windows.listWindows(target: .application(app.name))
                    windows.append(contentsOf: appWindows)
                }
                
                // Find the target window
                let window: ServiceWindowInfo
                if let windowId = windowId {
                    guard let targetWindow = windows.first(where: { $0.windowID == windowId }) else {
                        throw PeekabooError.windowNotFound(criteria: "ID \(windowId)")
                    }
                    window = targetWindow
                } else {
                    guard let targetWindow = windows.first(where: { window in
                        var matches = true
                        if let titleFilter = title {
                            matches = matches && window.title.lowercased().contains(titleFilter.lowercased())
                        }
                        // Note: ServiceWindowInfo doesn't have applicationName, so we can't filter by app here
                        return matches
                    }) else {
                        var criteria = ""
                        if let titleValue = title { criteria += "title '\(titleValue)' " }
                        if let appNameValue = appName { criteria += "app '\(appNameValue)' " }
                        throw PeekabooError.windowNotFound(criteria: criteria.trimmingCharacters(in: .whitespaces))
                    }
                    window = targetWindow
                }
                
                // Focus the window
                try await context.windows.focusWindow(target: .windowId(window.windowID))
                
                return .success(
                    "Focused window: \(window.title)",
                    metadata: ["window": window.title,
                               "window_id": String(window.windowID)]
                )
            }
        )
    }
    
    /// Create the resize window tool
    func createResizeWindowTool() -> Tool<PeekabooServices> {
        createTool(
            name: "resize_window",
            description: "Resize and/or move a window",
            parameters: .object(
                properties: [
                    "title": ParameterSchema.string(description: "Window title (partial match)"),
                    "app": ParameterSchema.string(description: "Application name"),
                    "width": ParameterSchema.integer(description: "New width in pixels"),
                    "height": ParameterSchema.integer(description: "New height in pixels"),
                    "x": ParameterSchema.integer(description: "New X position"),
                    "y": ParameterSchema.integer(description: "New Y position"),
                    "preset": ParameterSchema.enumeration(
                        ["maximize", "center", "left_half", "right_half", "top_half", "bottom_half"],
                        description: "Preset size/position"
                    )
                ],
                required: []
            ),
            handler: { params, context in
                let title = params.string("title", default: nil)
                let appName = params.string("app", default: nil)
                let width = params.int("width", default: nil)
                let height = params.int("height", default: nil)
                let x = params.int("x", default: nil)
                let y = params.int("y", default: nil)
                let preset = params.string("preset", default: nil)
                
                guard title != nil || appName != nil else {
                    throw PeekabooError.invalidInput("Either 'title' or 'app' must be provided")
                }
                
                // Find the window
                // Get all windows from all applications
                let apps = try await context.applications.listApplications()
                var windows: [ServiceWindowInfo] = []
                for app in apps {
                    let appWindows = try await context.windows.listWindows(target: .application(app.name))
                    windows.append(contentsOf: appWindows)
                }
                guard let window = windows.first(where: { window in
                    var matches = true
                    if let titleFilter = title {
                        matches = matches && window.title.lowercased().contains(titleFilter.lowercased())
                    }
                    // Note: ServiceWindowInfo doesn't have applicationName, so we can't filter by app here
                    return matches
                }) else {
                    var criteriaItems: [String] = []
                    if let titleValue = title {
                        criteriaItems.append("title '\(titleValue)'")
                    }
                    if let appNameValue = appName {
                        criteriaItems.append("app '\(appNameValue)'")
                    }
                    let criteria = criteriaItems.joined(separator: " ")
                    throw PeekabooError.windowNotFound(criteria: criteria)
                }
                
                // Calculate new bounds
                var newBounds = window.bounds
                
                if let preset = preset {
                    // Get screen bounds
                    let screenBounds = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
                    
                    switch preset {
                    case "maximize":
                        newBounds = screenBounds
                    case "center":
                        newBounds.origin.x = (screenBounds.width - newBounds.width) / 2
                        newBounds.origin.y = (screenBounds.height - newBounds.height) / 2
                    case "left_half":
                        newBounds = CGRect(
                            x: screenBounds.minX,
                            y: screenBounds.minY,
                            width: screenBounds.width / 2,
                            height: screenBounds.height
                        )
                    case "right_half":
                        newBounds = CGRect(
                            x: screenBounds.midX,
                            y: screenBounds.minY,
                            width: screenBounds.width / 2,
                            height: screenBounds.height
                        )
                    case "top_half":
                        newBounds = CGRect(
                            x: screenBounds.minX,
                            y: screenBounds.midY,
                            width: screenBounds.width,
                            height: screenBounds.height / 2
                        )
                    case "bottom_half":
                        newBounds = CGRect(
                            x: screenBounds.minX,
                            y: screenBounds.minY,
                            width: screenBounds.width,
                            height: screenBounds.height / 2
                        )
                    default:
                        throw PeekabooError.invalidInput("Unknown preset: \(preset)")
                    }
                } else {
                    // Apply individual parameters
                    if let x = x { newBounds.origin.x = CGFloat(x) }
                    if let y = y { newBounds.origin.y = CGFloat(y) }
                    if let width = width { newBounds.size.width = CGFloat(width) }
                    if let height = height { newBounds.size.height = CGFloat(height) }
                }
                
                // Apply the new bounds
                try await context.windows.setWindowBounds(
                    target: .windowId(window.windowID),
                    bounds: newBounds
                )
                
                var output = "Window '\(window.title)' "
                if let preset = preset {
                    output += preset.replacingOccurrences(of: "_", with: " ")
                } else {
                    output += "resized/moved to "
                    output += "(\(Int(newBounds.origin.x)), \(Int(newBounds.origin.y))) "
                    output += "size: \(Int(newBounds.width))x\(Int(newBounds.height))"
                }
                
                return .success(
                    output,
                    metadata: [
                        "window": window.title,
                        "x": String(Int(newBounds.origin.x)),
                        "y": String(Int(newBounds.origin.y)),
                        "width": String(Int(newBounds.width)),
                        "height": String(Int(newBounds.height))
                    ]
                )
            }
        )
    }
}