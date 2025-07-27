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
                
                try await context.dock.launchFromDock(appName: appName)
                
                // Wait a moment for launch
                try await Task.sleep(nanoseconds: TimeInterval.mediumDelay.nanoseconds)
                
                // Verify launch
                let apps = try await context.applications.listApplications()
                let launched = apps.contains { 
                    $0.name.lowercased() == appName.lowercased() 
                }
                
                if launched {
                    return .success(
                        "Successfully launched \(appName) from Dock",
                        metadata: ["app": appName]
                    )
                } else {
                    return .success(
                        "Clicked \(appName) in Dock (app may be starting)",
                        metadata: ["app": appName]
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
                let section = try? params.string("section", default: "all") ?? "all"
                
                let dockItems = try await context.dock.listDockItems(includeAll: true)
                
                if dockItems.isEmpty {
                    return .success("No items found in Dock")
                }
                
                var output = "Dock items:\n\n"
                
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
                
                // Group by type
                let grouped = Dictionary(grouping: filteredItems) { $0.itemType }
                
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
                        "section": section ?? "all"
                    ]
                )
            }
        )
    }
}