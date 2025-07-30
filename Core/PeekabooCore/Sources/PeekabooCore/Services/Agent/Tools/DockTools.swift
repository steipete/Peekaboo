import Foundation
import CoreGraphics
import AXorcist

// MARK: - Dock Tools

/// Dock interaction tools for launching apps and listing dock items
@available(macOS 14.0, *)
extension PeekabooAgentService {
    
    /// Create the dock launch tool
    func createDockLaunchTool() -> Tool<PeekabooServices> {
        createTool(
            name: "dock_launch",
            description: "Launch an application from the Dock",
            parameters: .object(
                properties: [
                    "name": ParameterSchema.string(description: "Application name as it appears in the Dock")
                ],
                required: ["name"]
            ),
            handler: { params, context in
                let appName = try params.string("name")
                
                // Check if app was already running before clicking
                let appsBeforeLaunchOutput = try await context.applications.listApplications()
                let wasRunning = appsBeforeLaunchOutput.data.applications.contains { 
                    $0.name.lowercased() == appName.lowercased() 
                }
                
                let startTime = Date()
                try await context.dock.launchFromDock(appName: appName)
                
                // Wait a moment for launch
                try await Task.sleep(nanoseconds: TimeInterval.mediumDelay.nanoseconds)
                
                // Verify launch and get window info
                let appsAfterLaunchOutput = try await context.applications.listApplications()
                if let launchedApp = appsAfterLaunchOutput.data.applications.first(where: { $0.name.lowercased() == appName.lowercased() }) {
                    let duration = Date().timeIntervalSince(startTime)
                    
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
                    
                    return .success(
                        output,
                        metadata: [
                            "app": launchedApp.name,
                            "wasRunning": String(wasRunning),
                            "windowCount": String(windows.count),
                            "duration": String(format: "%.2fs", duration)
                        ]
                    )
                } else {
                    let duration = Date().timeIntervalSince(startTime)
                    return .success(
                        "Clicked \(appName) in Dock (app may be starting)",
                        metadata: [
                            "app": appName,
                            "wasRunning": String(wasRunning),
                            "duration": String(format: "%.2fs", duration)
                        ]
                    )
                }
            }
        )
    }
    
    /// Create the list dock tool
    func createListDockTool() -> Tool<PeekabooServices> {
        createTool(
            name: "list_dock",
            description: "List all items in the Dock",
            parameters: .object(
                properties: [
                    "section": ParameterSchema.enumeration(
                        ["apps", "recent", "all"],
                        description: "Dock section to list (default: all)"
                    )
                ],
                required: []
            ),
            handler: { params, context in
                let section = params.string("section", default: "all") ?? "all"
                
                let startTime = Date()
                let dockItems = try await context.dock.listDockItems(includeAll: true)
                let duration = Date().timeIntervalSince(startTime)
                
                if dockItems.isEmpty {
                    return .success("No items found in Dock")
                }
                
                // Filter by section if requested
                let filteredItems: [DockItem]
                switch section {
                case "apps":
                    filteredItems = dockItems.filter { $0.itemType == .application }
                case "recent":
                    // Recent items are typically folders
                    filteredItems = dockItems.filter { $0.itemType == .folder }
                default:
                    filteredItems = dockItems
                }
                
                // Group by type and count
                let grouped = Dictionary(grouping: filteredItems) { $0.itemType }
                let appCount = grouped[.application]?.count ?? 0
                let runningCount = grouped[.application]?.filter { $0.isRunning == true }.count ?? 0
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
                
                return .success(
                    output.trimmingCharacters(in: .whitespacesAndNewlines),
                    metadata: [
                        "totalCount": String(filteredItems.count),
                        "appCount": String(appCount),
                        "runningCount": String(runningCount),
                        "folderCount": String(folderCount),
                        "section": section,
                        "duration": String(format: "%.2fs", duration),
                        "summary": summary
                    ]
                )
            }
        )
    }
}