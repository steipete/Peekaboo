import Foundation
import CoreGraphics
import AppKit
import AXorcist
import OSLog

// MARK: - Window Management Tools

/// Window management tools for listing, focusing, and manipulating windows
@available(macOS 14.0, *)
extension PeekabooAgentService {
    
    private static let logger = Logger(subsystem: "boo.peekaboo.core", category: "WindowManagementTools")
    
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
                
                var windows: [ServiceWindowInfo] = []
                
                if let appFilter = appFilter {
                    // If app filter is specified, only get windows from that app
                    let apps = try await context.applications.listApplications()
                    if let targetApp = apps.first(where: { $0.name.lowercased().contains(appFilter.lowercased()) }) {
                        windows = try await context.windows.listWindows(target: .application(targetApp.name))
                    }
                } else {
                    // For all windows, process apps sequentially to avoid AX race conditions
                    // AX elements are not thread-safe and must be accessed from main thread
                    let apps = try await context.applications.listApplications()
                    
                    // Filter to only regular applications (not background services)
                    var regularApps: [ServiceApplicationInfo] = []
                    for app in apps {
                        // Skip apps without bundle ID (system processes)
                        guard app.bundleIdentifier != nil else { continue }
                        
                        // Skip known problematic or background-only apps
                        let skipList = [
                            "com.apple.WebKit.WebContent",
                            "com.apple.WebKit.GPU",
                            "com.apple.WebKit.Networking",
                            "com.apple.SafariServices.SafariServicesApp",
                            "com.apple.appkit.xpc.openAndSavePanelService"
                        ]
                        if let bundleId = app.bundleIdentifier,
                           skipList.contains(where: { bundleId.contains($0) }) {
                            continue
                        }
                        
                        // Only include apps that are likely to have windows
                        // Include all apps that passed the filter
                        regularApps.append(app)
                    }
                    
                    Self.logger.debug("Checking \(regularApps.count) regular apps for windows (filtered from \(apps.count) total)")
                    
                    // Process each app sequentially without any concurrent operations
                    // This ensures all AX operations stay on the main thread
                    for app in regularApps {
                        do {
                            // For now, skip timeout mechanism to ensure thread safety
                            // TODO: Implement a main-thread-safe timeout mechanism
                            let appWindows = try await context.windows.listWindows(target: .application(app.name))
                            windows.append(contentsOf: appWindows)
                        } catch {
                            // Skip apps that fail
                            Self.logger.debug("Error getting windows for \(app.name): \(error)")
                        }
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
                    metadata: [
                        "count": String(windows.count),
                        "app": appFilter ?? "all"
                    ]
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
                
                // Get windows more efficiently based on search criteria
                var windows: [ServiceWindowInfo] = []
                
                if let appName = appName {
                    // If app is specified, only search that app
                    windows = try await context.windows.listWindows(target: .application(appName))
                } else if let title = title {
                    // If only title is specified, use title-based search
                    windows = try await context.windows.listWindows(target: .title(title))
                } else {
                    // Only window ID specified - need to search all apps
                    let apps = try await context.applications.listApplications()
                    
                    // Process each app sequentially without any concurrent operations
                    // This ensures all AX operations stay on the main thread
                    for app in apps {
                        do {
                            let appWindows = try await context.windows.listWindows(target: .application(app.name))
                            windows.append(contentsOf: appWindows)
                        } catch {
                            // Skip apps that fail
                            Self.logger.debug("Error getting windows for \(app.name): \(error)")
                        }
                    }
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
                    "window_id": ParameterSchema.integer(description: "Specific window ID"),
                    "frontmost": ParameterSchema.boolean(description: "Use the frontmost window"),
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
            handler: { (params: ToolParameterParser, context: PeekabooServices) in
                let title = params.string("title", default: nil)
                let appName = params.string("app", default: nil)
                let windowId = params.int("window_id", default: nil)
                let frontmost = params.bool("frontmost", default: false)
                let width = params.int("width", default: nil)
                let height = params.int("height", default: nil)
                let x = params.int("x", default: nil)
                let y = params.int("y", default: nil)
                let preset = params.string("preset", default: nil)
                
                // Validate that we have some way to identify the window
                guard title != nil || appName != nil || windowId != nil || frontmost else {
                    throw PeekabooError.invalidInput("Must provide either 'title', 'app', 'window_id', or 'frontmost:true' to identify the window")
                }
                
                // Find the window efficiently
                var windows: [ServiceWindowInfo] = []
                let window: ServiceWindowInfo
                
                if frontmost {
                    // Get the frontmost application first
                    let frontApp = try await context.applications.getFrontmostApplication()
                    
                    // Then get its windows
                    windows = try await context.windows.listWindows(target: .application(frontApp.name))
                    
                    guard let frontWindow = windows.first else {
                        throw PeekabooError.windowNotFound(criteria: "frontmost window for \(frontApp.name)")
                    }
                    window = frontWindow
                } else if let windowId = windowId {
                    // If window ID is specified, search all apps for that specific window
                    let apps = try await context.applications.listApplications()
                    var foundWindow: ServiceWindowInfo? = nil
                    
                    for app in apps {
                        do {
                            let appWindows = try await context.windows.listWindows(target: .application(app.name))
                            if let found = appWindows.first(where: { $0.windowID == windowId }) {
                                foundWindow = found
                                break
                            }
                        } catch {
                            // Skip apps that fail
                            Self.logger.debug("Error getting windows for \(app.name): \(error)")
                        }
                    }
                    
                    guard let found = foundWindow else {
                        throw PeekabooError.windowNotFound(criteria: "window with ID \(windowId)")
                    }
                    window = found
                } else {
                    // Search by title and/or app name
                    if let appName = appName {
                        // If app is specified, only search that app
                        windows = try await context.windows.listWindows(target: .application(appName))
                    } else if let title = title {
                        // If only title is specified, use title-based search
                        windows = try await context.windows.listWindows(target: .title(title))
                    } else {
                        // Need to search all apps - process sequentially to avoid AX race conditions
                        let apps = try await context.applications.listApplications()
                        
                        for app in apps {
                            do {
                                let appWindows = try await context.windows.listWindows(target: .application(app.name))
                                windows.append(contentsOf: appWindows)
                            } catch {
                                // Skip apps that fail
                                Self.logger.debug("Error getting windows for \(app.name): \(error)")
                            }
                        }
                    }
                    guard let foundWindow = windows.first(where: { window in
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
                    window = foundWindow
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
    
    /// Create the list spaces tool
    func createListSpacesTool() -> Tool<PeekabooServices> {
        createTool(
            name: "list_spaces",
            description: "List all macOS Spaces (virtual desktops)",
            parameters: .object(
                properties: [:],
                required: []
            ),
            handler: { _, context in
                let spaceService = SpaceManagementService()
                let spaces = spaceService.getAllSpaces()
                
                if spaces.isEmpty {
                    return .success("No Spaces found")
                }
                
                var output = "Found \(spaces.count) Space(s):\n\n"
                
                for (index, space) in spaces.enumerated() {
                    output += "Space \(index + 1):\n"
                    output += "  • ID: \(space.id)\n"
                    output += "  • Type: \(space.type.rawValue)\n"
                    output += "  • Active: \(space.isActive ? "Yes" : "No")\n"
                    if let displayID = space.displayID {
                        output += "  • Display: \(displayID)\n"
                    }
                    output += "\n"
                }
                
                return .success(
                    output.trimmingCharacters(in: .whitespacesAndNewlines),
                    metadata: ["count": String(spaces.count)]
                )
            }
        )
    }
    
    /// Create the switch space tool
    func createSwitchSpaceTool() -> Tool<PeekabooServices> {
        createTool(
            name: "switch_space",
            description: "Switch to a different macOS Space (virtual desktop)",
            parameters: .object(
                properties: [
                    "space_number": ParameterSchema.integer(description: "Space number to switch to (1-based)")
                ],
                required: ["space_number"]
            ),
            handler: { params, context in
                guard let spaceNumber = params.int("space_number", default: nil) else {
                    throw PeekabooError.invalidInput("space_number is required")
                }
                
                // Get space info
                let spaceService = SpaceManagementService()
                let spaces = spaceService.getAllSpaces()
                
                guard spaceNumber > 0 && spaceNumber <= spaces.count else {
                    throw PeekabooError.invalidInput("Invalid space number. Available spaces: 1-\(spaces.count)")
                }
                
                let targetSpace = spaces[spaceNumber - 1]
                let spaceId = targetSpace.id
                
                // Switch to space
                let spaceServiceForSwitch = SpaceManagementService()
                try await spaceServiceForSwitch.switchToSpace(spaceId)
                
                // Give it time to switch
                try? await Task.sleep(nanoseconds: 500_000_000)
                
                return .success(
                    "Switched to Space \(spaceNumber)",
                    metadata: ["space_id": String(spaceId)]
                )
            }
        )
    }
    
    /// Create the move window to space tool
    func createMoveWindowToSpaceTool() -> Tool<PeekabooServices> {
        createTool(
            name: "move_window_to_space",
            description: "Move a window to a different macOS Space (virtual desktop)",
            parameters: .object(
                properties: [
                    "window_id": ParameterSchema.integer(description: "Window ID to move"),
                    "space_number": ParameterSchema.integer(description: "Target space number (1-based)"),
                    "bring_to_current": ParameterSchema.boolean(description: "Move window to current space instead")
                ],
                required: []
            ),
            handler: { params, context in
                let windowId = params.int("window_id", default: nil)
                let spaceNumber = params.int("space_number", default: nil)
                let bringToCurrent = params.bool("bring_to_current", default: false)
                
                guard let windowId = windowId else {
                    throw PeekabooError.invalidInput("window_id is required")
                }
                
                if bringToCurrent {
                    let spaceService = SpaceManagementService()
                    try spaceService.moveWindowToCurrentSpace(windowID: CGWindowID(windowId))
                    return .success("Moved window to current Space")
                } else {
                    guard let spaceNumber = spaceNumber else {
                        throw PeekabooError.invalidInput("Either space_number or bring_to_current must be specified")
                    }
                    
                    let spaceService = SpaceManagementService()
                    let spaces = spaceService.getAllSpaces()
                    guard spaceNumber > 0 && spaceNumber <= spaces.count else {
                        throw PeekabooError.invalidInput("Invalid space number. Available spaces: 1-\(spaces.count)")
                    }
                    
                    let targetSpace = spaces[spaceNumber - 1]
                    try spaceService.moveWindowToSpace(windowID: CGWindowID(windowId), spaceID: targetSpace.id)
                    
                    return .success("Moved window to Space \(spaceNumber)")
                }
            }
        )
    }
}