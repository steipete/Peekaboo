import AppKit
import AXorcist
import CoreGraphics
import Foundation
import OSLog
import Tachikoma

// MARK: - Window Management Tools

/// Window management tools for listing, focusing, and manipulating windows
@available(macOS 14.0, *)
extension PeekabooAgentService {
    private static let logger = Logger(subsystem: "boo.peekaboo.core", category: "WindowManagementTools")

    /// Create the list windows tool
    func createListWindowsTool() -> Tachikoma.AgentTool {
        Tachikoma.AgentTool(
            name: "list_windows",
            description: "List all visible windows across all applications. Uses fast CGWindowList API when screen recording permission is granted, with automatic fallback to accessibility API. Results are returned quickly with built-in timeout protection to prevent hangs.",
            parameters: Tachikoma.AgentToolParameters(
                properties: [
                    Tachikoma.AgentToolParameterProperty(
                        name: "app",
                        type: .string,
                        description: "Optional: Filter windows by application name"),
                ],
                required: []),
            execute: { [services] params in
                let appFilter = params.optionalStringValue("app")

                var windows: [ServiceWindowInfo] = []

                if let appFilter {
                    // If app filter is specified, only get windows from that app
                    let appsOutput = try await services.applications.listApplications()
                    if let targetApp = appsOutput.data.applications
                        .first(where: { $0.name.lowercased().contains(appFilter.lowercased()) })
                    {
                        // Use applications service for UnifiedToolOutput
                        let windowsOutput = try await services.applications.listWindows(
                            for: targetApp.name,
                            timeout: nil)
                        windows = windowsOutput.data.windows
                    }
                } else {
                    // For all windows, process apps sequentially to avoid AX race conditions
                    // AX elements are not thread-safe and must be accessed from main thread
                    let appsOutput = try await services.applications.listApplications()

                    // Filter to only regular applications (not background services)
                    var regularApps: [ServiceApplicationInfo] = []
                    for app in appsOutput.data.applications {
                        // Skip apps without bundle ID (system processes)
                        guard app.bundleIdentifier != nil else { continue }

                        // Skip known problematic or background-only apps
                        let skipList = [
                            "com.apple.WebKit.WebContent",
                            "com.apple.WebKit.GPU",
                            "com.apple.WebKit.Networking",
                            "com.apple.SafariServices.SafariServicesApp",
                            "com.apple.appkit.xpc.openAndSavePanelService",
                            "com.apple.Safari.CacheDeleteExtension",
                            "com.apple.Safari.SafeBrowsing.Service",
                            "com.apple.Safari.History",
                            "com.apple.SafariServices",
                            "com.apple.dt.Xcode.DeveloperSystemPolicyService",
                            "com.apple.CoreSimulator",
                            "com.apple.iphonesimulator",
                            "com.apple.accessibility",
                            "com.apple.ViewBridgeAuxiliary",
                            "com.apple.hiservices-xpcservice",
                            "com.apple.AXVisualSupportAgent",
                            "com.apple.universalaccessAuthWarn",
                        ]
                        if let bundleId = app.bundleIdentifier,
                           skipList.contains(where: { bundleId.contains($0) })
                        {
                            continue
                        }

                        // Skip apps that are hidden (they likely don't have visible windows)
                        if app.isHidden {
                            continue
                        }

                        // Only include apps that are likely to have windows
                        // Include all apps that passed the filter
                        regularApps.append(app)
                    }

                    // Create a local logger to avoid @MainActor isolation issues
                    let localLogger = Logger(subsystem: "boo.peekaboo.core", category: "WindowTools")
                    localLogger.debug(
                        "Checking \(regularApps.count) regular apps for windows (filtered from \(appsOutput.data.applications.count) total)")

                    // Process each app sequentially without any concurrent operations
                    // This ensures all AX operations stay on the main thread
                    for app in regularApps {
                        do {
                            // Use a main-thread-safe timeout mechanism
                            let windowsResult = try await withMainThreadTimeout(seconds: 5.0) {
                                try await services.applications.listWindows(for: app.name, timeout: nil)
                            }

                            if let windowsOutput = windowsResult {
                                windows.append(contentsOf: windowsOutput.data.windows)
                            } else {
                                localLogger.debug("Timeout getting windows for \(app.name)")
                            }
                        } catch {
                            // Skip apps that fail
                            localLogger.debug("Error getting windows for \(app.name): \(error)")
                        }
                    }
                }

                if windows.isEmpty {
                    let message = if let appFilter {
                        "No windows found for application '\(appFilter)'"
                    } else {
                        "No windows found"
                    }
                    return .string(message)
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

                return .string(
                    output.trimmingCharacters(in: .whitespacesAndNewlines))
            })
    }

    /// Create the focus window tool
    func createFocusWindowTool() -> Tachikoma.AgentTool {
        Tachikoma.AgentTool(
            name: "focus_window",
            description: "Bring a window to the front and give it focus",
            parameters: Tachikoma.AgentToolParameters(
                properties: [
                    Tachikoma.AgentToolParameterProperty(
                        name: "title",
                        type: .string,
                        description: "Window title to search for (partial match supported)"),
                    Tachikoma.AgentToolParameterProperty(
                        name: "app",
                        type: .string,
                        description: "Application name"),
                    Tachikoma.AgentToolParameterProperty(
                        name: "window_id",
                        type: .integer,
                        description: "Specific window ID"),
                ],
                required: []),
            execute: { [services] params in
                let localLogger = Logger(subsystem: "boo.peekaboo.core", category: "WindowTools")
                let title = params.optionalStringValue("title")
                let appName = params.optionalStringValue("app")
                let windowId = params.optionalIntegerValue("window_id")

                // Require at least one parameter
                guard title != nil || appName != nil || windowId != nil else {
                    throw PeekabooError.invalidInput("At least one of 'title', 'app', or 'window_id' must be provided")
                }

                // First ensure the app is running and not hidden
                if let appName {
                    // Get running applications
                    let appsOutput = try await services.applications.listApplications()
                    if let app = appsOutput.data.applications
                        .first(where: { $0.name.lowercased() == appName.lowercased() })
                    {
                        // Activate the application first
                        try await services.applications.activateApplication(identifier: app.bundleIdentifier ?? app.name)

                        // Give it a moment to activate
                        try await Task.sleep(nanoseconds: TimeInterval.mediumDelay.nanoseconds)
                    }
                }

                // Get windows more efficiently based on search criteria
                var windows: [ServiceWindowInfo] = []

                if let appName, let title {
                    // OPTIMIZED: Use the new applicationAndTitle case for efficient searching
                    windows = try await services.windows.listWindows(target: .applicationAndTitle(
                        app: appName,
                        title: title))
                } else if let appName {
                    // If only app is specified, get all windows from that app
                    windows = try await services.windows.listWindows(target: .application(appName))
                } else if let title {
                    // If only title is specified, use title-based search (searches all apps)
                    windows = try await services.windows.listWindows(target: .title(title))
                } else {
                    // Only window ID specified - need to search all apps
                    let appsOutput = try await services.applications.listApplications()

                    // Process each app sequentially without any concurrent operations
                    // This ensures all AX operations stay on the main thread
                    for app in appsOutput.data.applications {
                        do {
                            let appWindows = try await services.windows.listWindows(target: .application(app.name))
                            windows.append(contentsOf: appWindows)
                        } catch {
                            // Skip apps that fail
                            localLogger.debug("Error getting windows for \(app.name): \(error)")
                        }
                    }
                }

                // Find the target window
                let window: ServiceWindowInfo
                if let windowId {
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

                // Get app info for better feedback
                let appInfo: ServiceApplicationInfo
                if let appName {
                    appInfo = try await services.applications.findApplication(identifier: appName)
                } else {
                    // Need to find which app owns this window
                    let appsOutput = try await services.applications.listApplications()
                    var foundApp: ServiceApplicationInfo?

                    for app in appsOutput.data.applications {
                        let appWindows = try await services.windows.listWindows(target: .application(app.name))
                        if appWindows.contains(where: { $0.windowID == window.windowID }) {
                            foundApp = app
                            break
                        }
                    }

                    guard let app = foundApp else {
                        throw PeekabooError.appNotFound("Could not determine app for window")
                    }
                    appInfo = app
                }

                // Focus the window
                let startTime = Date()
                try await services.windows.focusWindow(target: .windowId(window.windowID))
                _ = Date().timeIntervalSince(startTime)

                // The window.windowID is already the system window ID
                let systemWindowID = window.windowID

                return .string(
                    "Focused \(appInfo.name) - \"\(window.title)\" (Window ID: \(systemWindowID))")
            })
    }

    /// Create the resize window tool
    func createResizeWindowTool() -> Tachikoma.AgentTool {
        let parameters = Tachikoma.AgentToolParameters(
            properties: [
                Tachikoma.AgentToolParameterProperty(
                    name: "title",
                    type: .string,
                    description: "Window title (partial match)"),
                Tachikoma.AgentToolParameterProperty(
                    name: "app",
                    type: .string,
                    description: "Application name"),
                Tachikoma.AgentToolParameterProperty(
                    name: "window_id",
                    type: .integer,
                    description: "Specific window ID"),
                Tachikoma.AgentToolParameterProperty(
                    name: "frontmost",
                    type: .boolean,
                    description: "Use the frontmost window"),
                Tachikoma.AgentToolParameterProperty(
                    name: "width",
                    type: .integer,
                    description: "New width in pixels"),
                Tachikoma.AgentToolParameterProperty(
                    name: "height",
                    type: .integer,
                    description: "New height in pixels"),
                Tachikoma.AgentToolParameterProperty(
                    name: "x",
                    type: .integer,
                    description: "New X position"),
                Tachikoma.AgentToolParameterProperty(
                    name: "y",
                    type: .integer,
                    description: "New Y position"),
                Tachikoma.AgentToolParameterProperty(
                    name: "preset",
                    type: .string,
                    description: "Preset size/position (maximize, center, left_half, right_half, top_half, bottom_half)"),
                Tachikoma.AgentToolParameterProperty(
                    name: "target_screen",
                    type: .integer,
                    description: "Move window to specific screen (0-based index)"),
                Tachikoma.AgentToolParameterProperty(
                    name: "screen_preset",
                    type: .string,
                    description: "Move window relative to screens (same, next, previous, primary)"),
            ],
            required: [])

        return Tachikoma.AgentTool(
            name: "resize_window",
            description: "Resize and/or move a window",
            parameters: parameters,
            execute: { [services] params in
                let localLogger = Logger(subsystem: "boo.peekaboo.core", category: "WindowTools")
                let title = params.optionalStringValue("title")
                let appName = params.optionalStringValue("app")
                let windowId = params.optionalIntegerValue("window_id")
                let frontmost = params.optionalBooleanValue("frontmost") ?? false
                let width = params.optionalIntegerValue("width")
                let height = params.optionalIntegerValue("height")
                let x = params.optionalIntegerValue("x")
                let y = params.optionalIntegerValue("y")
                let preset = params.optionalStringValue("preset")
                let targetScreen = params.optionalIntegerValue("target_screen")
                let screenPreset = params.optionalStringValue("screen_preset")

                // Log the resize request for debugging
                var searchCriteria: [String] = []
                if let title { searchCriteria.append("title='\(title)'") }
                if let appName { searchCriteria.append("app='\(appName)'") }
                if let windowId { searchCriteria.append("id=\(windowId)") }
                if frontmost { searchCriteria.append("frontmost=true") }

                var resizeParams: [String] = []
                if let width { resizeParams.append("width=\(width)") }
                if let height { resizeParams.append("height=\(height)") }
                if let x { resizeParams.append("x=\(x)") }
                if let y { resizeParams.append("y=\(y)") }
                if let preset { resizeParams.append("preset=\(preset)") }
                if let targetScreen { resizeParams.append("targetScreen=\(targetScreen)") }
                if let screenPreset { resizeParams.append("screenPreset=\(screenPreset)") }

                localLogger
                    .info(
                        "resize_window: Searching for window with [\(searchCriteria.joined(separator: ", "))], resize params: [\(resizeParams.joined(separator: ", "))]")

                // Validate that we have some way to identify the window
                guard title != nil || appName != nil || windowId != nil || frontmost else {
                    throw PeekabooError
                        .invalidInput(
                            "Must provide either 'title', 'app', 'window_id', or 'frontmost:true' to identify the window")
                }

                // Find the window efficiently
                var windows: [ServiceWindowInfo] = []
                let window: ServiceWindowInfo

                if frontmost {
                    // Get the frontmost application first
                    let frontApp = try await services.applications.getFrontmostApplication()

                    // Then get its windows
                    windows = try await services.windows.listWindows(target: .application(frontApp.name))

                    guard let frontWindow = windows.first else {
                        throw PeekabooError.windowNotFound(criteria: "frontmost window for \(frontApp.name)")
                    }
                    window = frontWindow
                } else if let windowId {
                    // If window ID is specified, search all apps for that specific window
                    let appsOutput = try await services.applications.listApplications()
                    var foundWindow: ServiceWindowInfo?

                    for app in appsOutput.data.applications {
                        do {
                            let appWindows = try await services.windows.listWindows(target: .application(app.name))
                            if let found = appWindows.first(where: { $0.windowID == windowId }) {
                                foundWindow = found
                                break
                            }
                        } catch {
                            // Skip apps that fail
                            localLogger.debug("Error getting windows for \(app.name): \(error)")
                        }
                    }

                    guard let found = foundWindow else {
                        localLogger
                            .error(
                                "Window not found with ID \(windowId). Searched \(appsOutput.data.applications.count) applications.")
                        throw PeekabooError.windowNotFound(criteria: "window with ID \(windowId)")
                    }
                    window = found
                } else {
                    // Search by title and/or app name
                    if let appName, let title {
                        // OPTIMIZED: Use the new applicationAndTitle case for efficient searching
                        windows = try await services.windows.listWindows(target: .applicationAndTitle(
                            app: appName,
                            title: title))
                        // No need to filter further - the service already filtered by title
                    } else if let appName {
                        // If only app is specified, get all windows from that app
                        windows = try await services.windows.listWindows(target: .application(appName))
                    } else if let title {
                        // If only title is specified, use title-based search (searches all apps)
                        windows = try await services.windows.listWindows(target: .title(title))
                    } else {
                        // Need to search all apps - process sequentially to avoid AX race conditions
                        let appsOutput = try await services.applications.listApplications()

                        for app in appsOutput.data.applications {
                            do {
                                let appWindows = try await services.windows.listWindows(target: .application(app.name))
                                windows.append(contentsOf: appWindows)
                            } catch {
                                // Skip apps that fail
                                localLogger.debug("Error getting windows for \(app.name): \(error)")
                            }
                        }
                    }

                    // For the optimized case where both app and title are provided, windows are already filtered
                    guard let foundWindow = (appName != nil && title != nil) ? windows.first : windows
                        .first(where: { window in
                            var matches = true
                            if let titleFilter = title {
                                matches = matches && window.title.lowercased().contains(titleFilter.lowercased())
                            }
                            // Note: ServiceWindowInfo doesn't have applicationName, so we can't filter by app here
                            return matches
                        })
                    else {
                        var criteriaItems: [String] = []
                        if let titleValue = title {
                            criteriaItems.append("title '\(titleValue)'")
                        }
                        if let appNameValue = appName {
                            criteriaItems.append("app '\(appNameValue)'")
                        }
                        let criteria = criteriaItems.joined(separator: " ")

                        // Log more helpful error message
                        localLogger
                            .error("Window not found matching \(criteria). Found \(windows.count) total windows.")
                        if !windows.isEmpty {
                            localLogger
                                .debug(
                                    "Available windows: \(windows.map { "\($0.title) (ID: \($0.windowID))" }.joined(separator: ", "))")
                        }

                        throw PeekabooError.windowNotFound(criteria: criteria)
                    }
                    window = foundWindow
                }

                // Calculate new bounds
                var newBounds = window.bounds

                // Determine target screen
                var targetScreenInfo: ScreenInfo?
                if let targetScreen {
                    // Use specific screen index
                    targetScreenInfo = await services.screens.screen(at: targetScreen)
                } else if let screenPreset {
                    // Use screen preset
                    let currentScreen = await services.screens.screenContainingWindow(bounds: window.bounds)
                    let screens = await services.screens.listScreens()

                    switch screenPreset {
                    case "primary":
                        targetScreenInfo = await services.screens.primaryScreen
                    case "next":
                        if let current = currentScreen, current.index < screens.count - 1 {
                            targetScreenInfo = screens[current.index + 1]
                        } else {
                            targetScreenInfo = screens.first // Wrap around
                        }
                    case "previous":
                        if let current = currentScreen, current.index > 0 {
                            targetScreenInfo = screens[current.index - 1]
                        } else {
                            targetScreenInfo = screens.last // Wrap around
                        }
                    case "same":
                        targetScreenInfo = currentScreen
                    default:
                        throw PeekabooError.invalidInput("Unknown screen preset: \(screenPreset)")
                    }
                } else {
                    // No screen targeting - use current screen or main
                    targetScreenInfo = await services.screens.screenContainingWindow(bounds: window.bounds)
                    if targetScreenInfo == nil {
                        targetScreenInfo = await services.screens.primaryScreen
                    }
                }

                if let preset {
                    // Get screen bounds from target screen
                    let screenBounds = targetScreenInfo?.frame ?? NSScreen.main?.frame ?? CGRect(
                        x: 0,
                        y: 0,
                        width: 1920,
                        height: 1080)

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
                            height: screenBounds.height)
                    case "right_half":
                        newBounds = CGRect(
                            x: screenBounds.midX,
                            y: screenBounds.minY,
                            width: screenBounds.width / 2,
                            height: screenBounds.height)
                    case "top_half":
                        newBounds = CGRect(
                            x: screenBounds.minX,
                            y: screenBounds.midY,
                            width: screenBounds.width,
                            height: screenBounds.height / 2)
                    case "bottom_half":
                        newBounds = CGRect(
                            x: screenBounds.minX,
                            y: screenBounds.minY,
                            width: screenBounds.width,
                            height: screenBounds.height / 2)
                    default:
                        throw PeekabooError.invalidInput("Unknown preset: \(preset)")
                    }
                } else {
                    // Apply individual parameters
                    if let x { newBounds.origin.x = CGFloat(x) }
                    if let y { newBounds.origin.y = CGFloat(y) }
                    if let width { newBounds.size.width = CGFloat(width) }
                    if let height { newBounds.size.height = CGFloat(height) }

                    // If we're moving to a different screen but no preset was specified,
                    // maintain relative position on the new screen
                    if targetScreen != nil || screenPreset != nil {
                        let currentScreen = await services.screens.screenContainingWindow(bounds: window.bounds)
                        if let currentScreen, let targetScreenInfo, currentScreen.index != targetScreenInfo.index {
                            // Calculate relative position on current screen
                            let relativeX = (window.bounds.minX - currentScreen.frame.minX) / currentScreen.frame.width
                            let relativeY = (window.bounds.minY - currentScreen.frame.minY) / currentScreen.frame.height

                            // Apply relative position to target screen (only if x/y not explicitly specified)
                            if x == nil {
                                newBounds.origin.x = targetScreenInfo.frame
                                    .minX + (relativeX * targetScreenInfo.frame.width)
                            }
                            if y == nil {
                                newBounds.origin.y = targetScreenInfo.frame
                                    .minY + (relativeY * targetScreenInfo.frame.height)
                            }
                        }
                    }
                }

                // Get app info for better feedback
                let appInfo: ServiceApplicationInfo
                if frontmost {
                    appInfo = try await services.applications.getFrontmostApplication()
                } else if let appName {
                    appInfo = try await services.applications.findApplication(identifier: appName)
                } else {
                    // Need to find which app owns this window
                    let appsOutput = try await services.applications.listApplications()
                    var foundApp: ServiceApplicationInfo?

                    for app in appsOutput.data.applications {
                        let appWindows = try await services.windows.listWindows(target: .application(app.name))
                        if appWindows.contains(where: { $0.windowID == window.windowID }) {
                            foundApp = app
                            break
                        }
                    }

                    guard let app = foundApp else {
                        throw PeekabooError.appNotFound("Could not determine app for window")
                    }
                    appInfo = app
                }

                // Apply the new bounds
                let startTime = Date()
                try await services.windows.setWindowBounds(
                    target: .windowId(window.windowID),
                    bounds: newBounds)
                _ = Date().timeIntervalSince(startTime)

                // The window.windowID is already the system window ID
                let systemWindowID = window.windowID

                var output = ""
                if let preset {
                    let presetName = preset.replacingOccurrences(of: "_", with: " ").capitalized
                    output = "\(presetName) \(appInfo.name) - \"\(window.title)\" (Window ID: \(systemWindowID))"
                    if preset == "maximize" {
                        output += " to \(Int(newBounds.width))x\(Int(newBounds.height))"
                    }
                } else {
                    output = "Resized \(appInfo.name) - \"\(window.title)\" (Window ID: \(systemWindowID)) to \(Int(newBounds.width))x\(Int(newBounds.height))"
                    if x != nil || y != nil {
                        output += " at (\(Int(newBounds.origin.x)), \(Int(newBounds.origin.y)))"
                    }
                }

                return .string(output)
            })
    }


    /// Create the list screens tool
    func createListScreensTool() -> Tachikoma.AgentTool {
        Tachikoma.AgentTool(
            name: "list_screens",
            description: "List all available displays/monitors with their properties",
            parameters: Tachikoma.AgentToolParameters(
                properties: [],
                required: []),
            execute: { [services] params in
                let screens = await services.screens.listScreens()

                if screens.isEmpty {
                    return .string("No screens found")
                }

                var output = "Found \(screens.count) screen(s):\n\n"

                for screen in screens {
                    output += "\(screen.index). \(screen.name)\(screen.isPrimary ? " (Primary)" : "")\n"
                    output += "   • Resolution: \(Int(screen.frame.width))×\(Int(screen.frame.height))\n"
                    output += "   • Position: \(Int(screen.frame.origin.x)),\(Int(screen.frame.origin.y))\n"
                    output += "   • Scale: \(screen.scaleFactor)x\(screen.scaleFactor > 1 ? " (Retina)" : "")\n"
                    output += "   • Display ID: \(screen.displayID)\n"

                    // Show visible area if different from full resolution
                    if screen.visibleFrame.size != screen.frame.size {
                        output += "   • Visible Area: \(Int(screen.visibleFrame.width))×\(Int(screen.visibleFrame.height))\n"
                    }
                    output += "\n"
                }

                output += "💡 Use screen index with 'see' tool to capture specific screens"

                return .string(
                    output.trimmingCharacters(in: .whitespacesAndNewlines))
            })
    }

}

// MARK: - Main Thread Timeout Utility

@MainActor
private func withMainThreadTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping () async throws -> T) async throws -> T?
{
    // Create a task for the operation
    let operationTask = Task { @MainActor in
        try await operation()
    }

    // Create a timeout task
    let timeoutTask = Task { @MainActor in
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        operationTask.cancel()
    }

    // Wait for the operation to complete
    do {
        let result = try await operationTask.value
        timeoutTask.cancel() // Cancel the timeout if operation succeeds
        return result
    } catch {
        timeoutTask.cancel()
        if operationTask.isCancelled {
            // Operation was cancelled due to timeout
            return nil
        } else {
            // Operation failed for another reason
            throw error
        }
    }
}
