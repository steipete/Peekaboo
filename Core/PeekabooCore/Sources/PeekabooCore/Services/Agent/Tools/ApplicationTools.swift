import AppKit
import AXorcist
import CoreGraphics
import Foundation
import Tachikoma

// MARK: - Tool Definitions

@available(macOS 14.0, *)
public struct ApplicationToolDefinitions {
    public static let listApps = UnifiedToolDefinition(
        name: "list_apps",
        commandName: "list-apps",
        abstract: "List all running applications",
        discussion: """
            Lists all currently running applications with their process IDs
            and active status.

            EXAMPLES:
              peekaboo list-apps
        """,
        category: .app,
        parameters: [],
        examples: [],
        agentGuidance: """
            AGENT TIPS:
            - Shows all running apps including background processes
            - Active app is marked with (active)
            - Use app names from this list for other commands
        """)

    public static let launchApp = UnifiedToolDefinition(
        name: "launch_app",
        commandName: "launch-app",
        abstract: "Launch an application",
        discussion: """
            Launches an application by name. If the app is already running,
            it will be brought to the front instead.

            EXAMPLES:
              peekaboo launch-app Safari
              peekaboo launch-app "Google Chrome" --no-wait
        """,
        category: .app,
        parameters: [
            ParameterDefinition(
                name: "name",
                type: .string,
                description: "Application name (e.g., 'Safari', 'TextEdit')",
                required: true,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .argument)),
            ParameterDefinition(
                name: "no-wait",
                type: .boolean,
                description: "Don't wait for the app to finish launching",
                required: false,
                defaultValue: "false",
                options: nil,
                cliOptions: CLIOptions(argumentType: .flag, longName: "no-wait")),
        ],
        examples: [
            #"{"name": "Safari"}"#,
            #"{"name": "TextEdit", "wait_for_launch": false}"#,
        ],
        agentGuidance: """
            AGENT TIPS:
            - If app is already running, it will just be activated
            - Shows window count after launch
            - Use exact app names from 'list_apps' for best results
            - Some apps may take time to show windows after launch
        """)
}

// MARK: - Application Tools

/// Application management tools for listing and launching apps
@available(macOS 14.0, *)
extension PeekabooAgentService {
    /// Create the list apps tool
    func createListAppsTool() -> Tool<PeekabooServices> {
        let definition = ApplicationToolDefinitions.listApps

        return createSimpleTool(
            name: definition.name,
            description: definition.agentDescription,
            execute: { _, context in
                let appsOutput = try await context.applications.listApplications()

                if appsOutput.data.applications.isEmpty {
                    return ToolOutput.success("No running applications found")
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

                return ToolOutput.success(
                    output.trimmingCharacters(in: .whitespacesAndNewlines))
            })
    }

    /// Create the launch app tool
    func createLaunchAppTool() -> Tool<PeekabooServices> {
        let definition = ApplicationToolDefinitions.launchApp

        return createTool(
            name: definition.name,
            description: definition.agentDescription,
            parameters: definition.toAgentParameters(),
            execute: { params, context in
                let appName = try params.stringValue("name")
                let waitForLaunch = params.boolValue("wait_for_launch", default: true)

                // First check if already running
                let runningAppsOutput = try await context.applications.listApplications()
                if let existingApp = runningAppsOutput.data.applications
                    .first(where: { $0.name.lowercased() == appName.lowercased() })
                {
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
                        identifier: existingApp.bundleIdentifier ?? existingApp.name)

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

                    return ToolOutput.success(statusMessage)
                }

                // Launch the app
                let launchedApp = try await context.applications.launchApplication(identifier: appName ?? "")

                if waitForLaunch {
                    // Wait a bit for the app to launch
                    try await Task.sleep(nanoseconds: TimeInterval.longDelay.nanoseconds)

                    // Verify it launched and get window info
                    let appsOutput = try await context.applications.listApplications()
                    if let verifiedApp = appsOutput.data.applications
                        .first(where: { $0.bundleIdentifier == launchedApp.bundleIdentifier })
                    {
                        // Get window information
                        let windows = try await context.windows.listWindows(target: .application(verifiedApp.name))

                        let windowDescription = if windows.isEmpty {
                            "no windows"
                        } else if windows.count == 1 {
                            "1 new window"
                        } else {
                            "\(windows.count) new windows"
                        }

                        return ToolOutput.success("Launched \(launchedApp.name) (\(windowDescription))")
                    } else {
                        throw PeekabooError.operationError(message: "\(appName) launched but is not responding")
                    }
                } else {
                    return ToolOutput.success("Launched \(launchedApp.name) (not waiting for completion)")
                }
            })
    }
}
