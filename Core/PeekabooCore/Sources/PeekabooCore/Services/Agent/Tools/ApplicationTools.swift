import Foundation
import CoreGraphics
import AXorcist
import AppKit

// MARK: - Application Tools

/// Application management tools for listing and launching apps
@available(macOS 14.0, *)
extension PeekabooAgentService {
    
    /// Create the list apps tool
    func createListAppsTool() -> Tool<PeekabooServices> {
        createSimpleTool(
            name: "list_apps",
            description: "List all running applications",
            handler: { context in
                let appsOutput = try await context.applications.listApplications()
                
                if appsOutput.data.applications.isEmpty {
                    return .success("No running applications found")
                }
                
                var output = "Running applications:\n\n"
                for app in appsOutput.data.applications.sorted(by: { $0.name < $1.name }) {
                    output += "• \(app.name)"
                    output += " [PID: \(app.processIdentifier)]"
                    if app.isActive {
                        output += " (active)"
                    }
                    output += "\n"
                }
                
                return .success(
                    output.trimmingCharacters(in: .whitespacesAndNewlines),
                    metadata: ["count": String(appsOutput.data.applications.count)]
                )
            }
        )
    }
    
    /// Create the launch app tool
    func createLaunchAppTool() -> Tool<PeekabooServices> {
        createTool(
            name: "launch_app",
            description: "Launch an application by name",
            parameters: .object(
                properties: [
                    "name": ParameterSchema.string(description: "Application name (e.g., 'Safari', 'TextEdit')"),
                    "wait_for_launch": ParameterSchema.boolean(description: "Wait for the app to finish launching (default: true)")
                ],
                required: ["name"]
            ),
            handler: { params, context in
                let appName = try params.string("name")
                let waitForLaunch = params.bool("wait_for_launch", default: true)
                
                // First check if already running
                let runningAppsOutput = try await context.applications.listApplications()
                if let existingApp = runningAppsOutput.data.applications.first(where: { $0.name.lowercased() == appName.lowercased() }) {
                    // Get window information
                    let windows = try await context.windows.listWindows(target: .application(existingApp.name))
                    
                    // Count window states
                    var normalWindows = 0
                    var minimizedWindows = 0
                    var fullscreenWindows = 0
                    
                    for window in windows {
                        if window.isMinimized {
                            minimizedWindows += 1
                        } else if window.bounds.size == NSScreen.main?.frame.size {
                            fullscreenWindows += 1
                        } else {
                            normalWindows += 1
                        }
                    }
                    
                    // App is already running, just activate it
                    try await context.applications.activateApplication(
                        identifier: existingApp.bundleIdentifier ?? existingApp.name
                    )
                    
                    var statusMessage = "\(existingApp.name) already running"
                    if windows.isEmpty {
                        statusMessage += " (no windows)"
                    } else if windows.count == 1 {
                        let window = windows[0]
                        if window.isMinimized {
                            statusMessage += " (1 window: minimized)"
                        } else if window.bounds.size == NSScreen.main?.frame.size {
                            statusMessage += " (1 window: fullscreen)"
                        } else {
                            statusMessage += " (1 window)"
                        }
                    } else {
                        statusMessage += " (\(windows.count) windows"
                        var stateDescriptions: [String] = []
                        if normalWindows > 0 {
                            stateDescriptions.append("\(normalWindows) normal")
                        }
                        if minimizedWindows > 0 {
                            stateDescriptions.append("\(minimizedWindows) minimized")
                        }
                        if fullscreenWindows > 0 {
                            stateDescriptions.append("\(fullscreenWindows) fullscreen")
                        }
                        if !stateDescriptions.isEmpty {
                            statusMessage += ": " + stateDescriptions.joined(separator: ", ")
                        }
                        statusMessage += ")"
                    }
                    
                    return .success(
                        statusMessage,
                        metadata: [
                            "app": existingApp.name,
                            "bundleId": existingApp.bundleIdentifier ?? "",
                            "wasRunning": "true",
                            "windowCount": String(windows.count),
                            "normalWindows": String(normalWindows),
                            "minimizedWindows": String(minimizedWindows),
                            "fullscreenWindows": String(fullscreenWindows)
                        ]
                    )
                }
                
                // Launch the app
                let launchedApp = try await context.applications.launchApplication(identifier: appName)
                
                if waitForLaunch {
                    // Wait a bit for the app to launch
                    try await Task.sleep(nanoseconds: TimeInterval.longDelay.nanoseconds)
                    
                    // Verify it launched and get window info
                    let appsOutput = try await context.applications.listApplications()
                    if let verifiedApp = appsOutput.data.applications.first(where: { $0.bundleIdentifier == launchedApp.bundleIdentifier }) {
                        // Get window information
                        let windows = try await context.windows.listWindows(target: .application(verifiedApp.name))
                        
                        let windowDescription = if windows.isEmpty {
                            "no windows"
                        } else if windows.count == 1 {
                            "1 new window"
                        } else {
                            "\(windows.count) new windows"
                        }
                        
                        return .success(
                            "Launched \(launchedApp.name) (\(windowDescription))",
                            metadata: [
                                "app": launchedApp.name,
                                "bundleId": launchedApp.bundleIdentifier ?? "",
                                "wasRunning": "false",
                                "windowCount": String(windows.count)
                            ]
                        )
                    } else {
                        throw PeekabooError.operationError(message: "\(appName) launched but is not responding")
                    }
                } else {
                    return .success(
                        "Launched \(launchedApp.name) (not waiting for completion)",
                        metadata: [
                            "app": launchedApp.name,
                            "bundleId": launchedApp.bundleIdentifier ?? "",
                            "wasRunning": "false"
                        ]
                    )
                }
            }
        )
    }
}