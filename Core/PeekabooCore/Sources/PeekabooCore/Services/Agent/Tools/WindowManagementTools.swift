import Foundation
import CoreGraphics
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
                    "app": .string(
                        description: "Optional: Filter windows by application name",
                        required: false
                    )
                ],
                required: []
            ),
            handler: { params, context in
                let appFilter = params.string("app")
                
                var windows = try await context.windowManagement.listWindows()
                
                // Apply app filter if specified
                if let appFilter = appFilter {
                    windows = windows.filter { 
                        $0.applicationName.lowercased().contains(appFilter.lowercased()) 
                    }
                }
                
                if windows.isEmpty {
                    let message = appFilter != nil 
                        ? "No windows found for application '\(appFilter!)'"
                        : "No windows found"
                    return .success(message)
                }
                
                // Group windows by application
                let grouped = Dictionary(grouping: windows) { $0.applicationName }
                
                var output = "Found \(windows.count) window(s):\n\n"
                
                for (app, appWindows) in grouped.sorted(by: { $0.key < $1.key }) {
                    output += "\(app):\n"
                    for window in appWindows {
                        output += "  • \(window.title.isEmpty ? "Untitled" : window.title)"
                        output += " [ID: \(window.windowID)]"
                        if window.isMinimized {
                            output += " (minimized)"
                        }
                        output += "\n"
                    }
                    output += "\n"
                }
                
                return .success(
                    output.trimmingCharacters(in: .whitespacesAndNewlines),
                    metadata: "count", String(windows.count),
                    "apps", grouped.keys.sorted().joined(separator: ",")
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
                    "title": .string(
                        description: "Window title to search for (partial match supported)",
                        required: false
                    ),
                    "app": .string(
                        description: "Application name",
                        required: false
                    ),
                    "window_id": .integer(
                        description: "Specific window ID",
                        required: false
                    )
                ],
                required: []
            ),
            handler: { params, context in
                let title = params.string("title")
                let appName = params.string("app")
                let windowId = params.int("window_id").map { CGWindowID($0) }
                
                // Require at least one parameter
                guard title != nil || appName != nil || windowId != nil else {
                    throw PeekabooError.invalidInput("At least one of 'title', 'app', or 'window_id' must be provided")
                }
                
                // First ensure the app is running and not hidden
                if let appName = appName {
                    // Get running applications
                    let apps = try await context.application.listApplications()
                    if let app = apps.findApp(byName: appName) {
                        // Activate the application first
                        try await context.application.activateApplication(bundleID: app.bundleIdentifier)
                        
                        // Give it a moment to activate
                        try await Task.sleep(nanoseconds: TimeInterval.mediumDelay.nanoseconds)
                    }
                }
                
                let windows = try await context.windowManagement.listWindows()
                
                // Find the target window
                let window: WindowInfo
                if let windowId = windowId {
                    window = try windows.findWindow(byID: windowId)
                } else {
                    guard let targetWindow = windows.first(where: { window in
                        var matches = true
                        if let title = title {
                            matches = matches && window.title.lowercased().contains(title.lowercased())
                        }
                        if let appName = appName {
                            matches = matches && window.applicationName.lowercased() == appName.lowercased()
                        }
                        return matches
                    }) else {
                        var criteria = ""
                        if let title = title { criteria += "title '\(title)' " }
                        if let appName = appName { criteria += "app '\(appName)' " }
                        throw PeekabooError.windowNotFound(criteria: criteria.trimmingCharacters(in: .whitespaces))
                    }
                    window = targetWindow
                }
                
                // Focus the window
                try await context.windowManagement.focusWindow(windowID: window.windowID)
                
                return .success(
                    "Focused window: \(window.title) (\(window.applicationName))",
                    metadata: "window", window.title,
                    "app", window.applicationName,
                    "window_id", String(window.windowID)
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
                    "title": .string(
                        description: "Window title (partial match)",
                        required: false
                    ),
                    "app": .string(
                        description: "Application name",
                        required: false
                    ),
                    "width": .integer(
                        description: "New width in pixels",
                        required: false
                    ),
                    "height": .integer(
                        description: "New height in pixels",
                        required: false
                    ),
                    "x": .integer(
                        description: "New X position",
                        required: false
                    ),
                    "y": .integer(
                        description: "New Y position",
                        required: false
                    ),
                    "preset": .string(
                        description: "Preset size/position",
                        required: false,
                        enum: ["maximize", "center", "left_half", "right_half", "top_half", "bottom_half"]
                    )
                ],
                required: []
            ),
            handler: { params, context in
                let title = params.string("title")
                let appName = params.string("app")
                let width = params.int("width")
                let height = params.int("height")
                let x = params.int("x")
                let y = params.int("y")
                let preset = params.string("preset")
                
                guard title != nil || appName != nil else {
                    throw PeekabooError.invalidInput("Either 'title' or 'app' must be provided")
                }
                
                // Find the window
                let windows = try await context.windowManagement.listWindows()
                guard let window = windows.first(where: { window in
                    var matches = true
                    if let title = title {
                        matches = matches && window.title.lowercased().contains(title.lowercased())
                    }
                    if let appName = appName {
                        matches = matches && window.applicationName.lowercased() == appName.lowercased()
                    }
                    return matches
                }) else {
                    let criteria = [
                        title.map { "title '\($0)'" },
                        appName.map { "app '\($0)'" }
                    ].compactMap { $0 }.joined(separator: " ")
                    throw PeekabooError.windowNotFound(criteria: criteria)
                }
                
                // Calculate new bounds
                var newBounds = CGRect(origin: window.position, size: window.size)
                
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
                try await context.windowManagement.moveWindow(
                    windowID: window.windowID,
                    to: newBounds.origin
                )
                
                if newBounds.size != window.size {
                    try await context.windowManagement.resizeWindow(
                        windowID: window.windowID,
                        to: newBounds.size
                    )
                }
                
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
                    metadata: "window", window.title,
                    "app", window.applicationName,
                    "x", String(Int(newBounds.origin.x)),
                    "y", String(Int(newBounds.origin.y)),
                    "width", String(Int(newBounds.width)),
                    "height", String(Int(newBounds.height))
                )
            }
        )
    }
}