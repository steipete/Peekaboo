import AXorcist
import CoreGraphics
import Foundation

// MARK: - Tool Definitions

@available(macOS 14.0, *)
public struct DockToolDefinitions {
    public static let dockLaunch = UnifiedToolDefinition(
        name: "dock_launch",
        commandName: "dock-launch",
        abstract: "Launch an application from the Dock",
        discussion: """
            Clicks on an application in the Dock to launch or activate it.
            If the app is already running, it will be brought to the front.
            
            EXAMPLES:
              peekaboo dock-launch Safari
              peekaboo dock-launch "Google Chrome"
              peekaboo dock-launch Terminal
        """,
        category: .app,
        parameters: [
            ParameterDefinition(
                name: "name",
                type: .string,
                description: "Application name as it appears in the Dock",
                required: true,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .argument)
            )
        ],
        examples: [
            #"{"name": "Safari"}"#,
            #"{"name": "Google Chrome"}"#
        ],
        agentGuidance: """
            AGENT TIPS:
            - Use exact names as they appear in the Dock
            - Shows window count after launch/activation
            - If app was already running, it just activates it
            - Some apps may take time to fully launch
            - Use 'list_dock' to see available apps
        """
    )
    
    public static let listDock = UnifiedToolDefinition(
        name: "list_dock",
        commandName: "list-dock",
        abstract: "List all items in the Dock",
        discussion: """
            Lists all items in the macOS Dock, including applications, folders,
            and recent items. Shows which apps are currently running.
            
            EXAMPLES:
              peekaboo list-dock
              peekaboo list-dock --section apps
              peekaboo list-dock --section recent
        """,
        category: .app,
        parameters: [
            ParameterDefinition(
                name: "section",
                type: .enumeration,
                description: "Dock section to list",
                required: false,
                defaultValue: "all",
                options: ["apps", "recent", "all"],
                cliOptions: CLIOptions(argumentType: .option)
            )
        ],
        examples: [
            #"{}"#,
            #"{"section": "apps"}"#,
            #"{"section": "recent"}"#
        ],
        agentGuidance: """
            AGENT TIPS:
            - Shows (running) indicator for active apps
            - 'recent' section shows recently used documents/folders
            - Use this to find exact app names for dock_launch
            - Dock items are listed in their visual order
            - Some items may be separators or special folders
        """
    )
}

// MARK: - Dock Tools

/// Dock interaction tools for launching apps and listing dock items
@available(macOS 14.0, *)
extension PeekabooAgentService {
    /// Create the dock launch tool
    func createDockLaunchTool() -> Tool<PeekabooServices> {
        let definition = DockToolDefinitions.dockLaunch
        
        return createTool(
            name: definition.name,
            description: definition.agentDescription,
            parameters: definition.toAgentParameters(),
            execute: { params, context in
                let appName = try params.string("name")

                // Check if app was already running before clicking
                let appsBeforeLaunchOutput = try await context.applications.listApplications()
                let wasRunning = appsBeforeLaunchOutput.data.applications.contains {
                    $0.name.lowercased() == appName?.lowercased() ?? ""
                }

                let startTime = Date()
                try await context.dock.launchFromDock(appName: appName)

                // Wait a moment for launch
                try await Task.sleep(nanoseconds: TimeInterval.mediumDelay.nanoseconds)

                // Verify launch and get window info
                let appsAfterLaunchOutput = try await context.applications.listApplications()
                if let launchedApp = appsAfterLaunchOutput.data.applications
                    .first(where: { $0.name.lowercased() == appName?.lowercased() ?? "" })
                {
                    let _ = Date().timeIntervalSince(startTime)

                    // Get window information
                    let windows = try await context.windows.listWindows(target: .application(launchedApp.name))

                    var output: String
                    if wasRunning {
                        output = "Activated \(launchedApp.name) from Dock (already running"
                        if windows.isEmpty {
                            output += ", no windows)"
                        } else if windows.count == 1 {
                            output += " with 1 window)"
                        } else {
                            output += " with \(windows.count) windows)"
                        }
                    } else {
                        output = "Launched \(launchedApp.name) from Dock (was not running"
                        if windows.isEmpty {
                            output += ", no windows yet)"
                        } else if windows.count == 1 {
                            output += ", opened 1 window)"
                        } else {
                            output += ", opened \(windows.count) windows)"
                        }
                    }

                    return .success(output)
                } else {
                    let _ = Date().timeIntervalSince(startTime)
                    return .success("Clicked \(appName) in Dock (app may be starting)")
                }
            })
    }

    /// Create the list dock tool
    func createListDockTool() -> Tool<PeekabooServices> {
        let definition = DockToolDefinitions.listDock
        
        return createTool(
            name: definition.name,
            description: definition.agentDescription,
            parameters: definition.toAgentParameters(),
            execute: { params, context in
                let section = params.string("section", default: "all") ?? "all"

                let startTime = Date()
                let dockItems = try await context.dock.listDockItems(includeAll: true)
                let _ = Date().timeIntervalSince(startTime)

                if dockItems.isEmpty {
                    return .success("No items found in Dock")
                }

                // Filter by section if requested
                let filteredItems: [DockItem] = switch section {
                case "apps":
                    dockItems.filter { $0.itemType == .application }
                case "recent":
                    // Recent items are typically folders
                    dockItems.filter { $0.itemType == .folder }
                default:
                    dockItems
                }

                // Group by type and count
                let grouped = Dictionary(grouping: filteredItems) { $0.itemType }
                let appCount = grouped[.application]?.count ?? 0
                let runningCount = grouped[.application]?.count(where: { $0.isRunning == true }) ?? 0
                let folderCount = grouped[.folder]?.count ?? 0
                let otherCount = grouped[.unknown]?.count ?? 0

                // Create summary
                var summary = "Listed \(filteredItems.count) Dock items"
                if section == "all" {
                    var details: [String] = []
                    if appCount > 0 {
                        var appDetail = "\(appCount) apps"
                        if runningCount > 0 {
                            appDetail += " (\(runningCount) running)"
                        }
                        details.append(appDetail)
                    }
                    if folderCount > 0 {
                        details.append("\(folderCount) folders")
                    }
                    if otherCount > 0 {
                        details.append("\(otherCount) other")
                    }
                    if !details.isEmpty {
                        summary += ": " + details.joined(separator: ", ")
                    }
                }

                // Format output
                var output = "Dock items:\n\n"

                // Show applications
                if let apps = grouped[.application], !apps.isEmpty {
                    output += "Applications:\n"
                    for app in apps {
                        output += "  • \(app.title)"
                        if app.isRunning == true {
                            output += " (running)"
                        }
                        output += "\n"
                    }
                    output += "\n"
                }

                // Show folders (which may include recent items)
                if let folders = grouped[.folder], !folders.isEmpty {
                    output += "Folders:\n"
                    for item in folders {
                        output += "  • \(item.title)\n"
                    }
                    output += "\n"
                }

                // Show other items
                if let other = grouped[.unknown], !other.isEmpty {
                    output += "Other:\n"
                    for item in other {
                        output += "  • \(item.title)\n"
                    }
                }

                return .success(output.trimmingCharacters(in: .whitespacesAndNewlines))
            })
    }
}
