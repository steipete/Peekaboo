import Foundation
import CoreGraphics
import AXorcist

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
                let apps = try await context.application.listApplications()
                
                if apps.isEmpty {
                    return .success("No running applications found")
                }
                
                var output = "Running applications:\n\n"
                for app in apps.sorted(by: { $0.name < $1.name }) {
                    output += "• \(app.name)"
                    if let pid = app.processIdentifier {
                        output += " [PID: \(pid)]"
                    }
                    if app.isActive {
                        output += " (active)"
                    }
                    output += "\n"
                }
                
                return .success(
                    output.trimmingCharacters(in: .whitespacesAndNewlines),
                    metadata: "count", String(apps.count)
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
                    "name": .string(
                        description: "Application name (e.g., 'Safari', 'TextEdit')",
                        required: true
                    ),
                    "wait_for_launch": .boolean(
                        description: "Wait for the app to finish launching (default: true)",
                        required: false
                    )
                ],
                required: ["name"]
            ),
            handler: { params, context in
                let appName = try params.string("name")
                let waitForLaunch = params.bool("wait_for_launch", default: true)
                
                // First check if already running
                let runningApps = try await context.application.listApplications()
                if let existingApp = runningApps.findApp(byName: appName) {
                    // App is already running, just activate it
                    try await context.application.activateApplication(
                        bundleID: existingApp.bundleIdentifier
                    )
                    return .success(
                        "\(appName) is already running and has been activated",
                        metadata: "app", existingApp.name,
                        "bundleId", existingApp.bundleIdentifier,
                        "wasRunning", "true"
                    )
                }
                
                // Launch the app
                let bundleId = try await context.application.launchApplication(name: appName)
                
                if waitForLaunch {
                    // Wait a bit for the app to launch
                    try await Task.sleep(nanoseconds: TimeInterval.longDelay.nanoseconds)
                    
                    // Verify it launched
                    let apps = try await context.application.listApplications()
                    if apps.contains(where: { $0.bundleIdentifier == bundleId }) {
                        return .success(
                            "Successfully launched \(appName)",
                            metadata: "app", appName,
                            "bundleId", bundleId,
                            "wasRunning", "false"
                        )
                    } else {
                        throw PeekabooError.operationError("\(appName) launched but is not responding")
                    }
                } else {
                    return .success(
                        "Launched \(appName) (not waiting for completion)",
                        metadata: "app", appName,
                        "bundleId", bundleId,
                        "wasRunning", "false"
                    )
                }
            }
        )
    }
}