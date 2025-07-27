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
                    "name": .string(
                        description: "Application name as it appears in the Dock",
                        required: true
                    )
                ],
                required: ["name"]
            ),
            handler: { params, context in
                let appName = try params.string("name")
                
                try await context.dock.launchFromDock(appName: appName)
                
                // Wait a moment for launch
                try await Task.sleep(nanoseconds: TimeInterval.mediumDelay.nanoseconds)
                
                // Verify launch
                let apps = try await context.application.listApplications()
                let launched = apps.contains { 
                    $0.name.lowercased() == appName.lowercased() 
                }
                
                if launched {
                    return .success(
                        "Successfully launched \(appName) from Dock",
                        metadata: "app", appName
                    )
                } else {
                    return .success(
                        "Clicked \(appName) in Dock (app may be starting)",
                        metadata: "app", appName
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
                    "section": .string(
                        description: "Dock section to list",
                        required: false,
                        enum: ["apps", "recent", "all"]
                    )
                ],
                required: []
            ),
            handler: { params, context in
                let section = params.string("section", default: "all") ?? "all"
                
                let dockItems = try await context.dock.listDockItems()
                
                if dockItems.isEmpty {
                    return .success("No items found in Dock")
                }
                
                var output = "Dock items:\n\n"
                
                // Filter by section if requested
                let filteredItems: [DockItem]
                switch section {
                case "apps":
                    filteredItems = dockItems.filter { $0.type == .application }
                case "recent":
                    filteredItems = dockItems.filter { $0.type == .recent }
                default:
                    filteredItems = dockItems
                }
                
                // Group by type
                let grouped = Dictionary(grouping: filteredItems) { $0.type }
                
                // Show applications
                if let apps = grouped[.application], !apps.isEmpty {
                    output += "Applications:\n"
                    for app in apps {
                        output += "  • \(app.name)"
                        if app.isRunning {
                            output += " (running)"
                        }
                        output += "\n"
                    }
                    output += "\n"
                }
                
                // Show recent items
                if let recent = grouped[.recent], !recent.isEmpty {
                    output += "Recent Items:\n"
                    for item in recent {
                        output += "  • \(item.name)\n"
                    }
                    output += "\n"
                }
                
                // Show other items
                if let other = grouped[.other], !other.isEmpty {
                    output += "Other:\n"
                    for item in other {
                        output += "  • \(item.name)\n"
                    }
                }
                
                return .success(
                    output.trimmingCharacters(in: .whitespacesAndNewlines),
                    metadata: "totalCount", String(filteredItems.count),
                    "section", section
                )
            }
        )
    }
}