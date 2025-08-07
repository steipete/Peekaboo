import AppKit
import Foundation
import TachikomaMCP
import MCP

/// MCP tool for listing various system items
public struct ListTool: MCPTool {
    public let name = "list"
    public let description = """
    Lists various system items on macOS, providing situational awareness.

    Capabilities:
    - Running Applications: Get a list of all currently running applications (names and bundle IDs).
    - Application Windows: For a specific application (identified by name or bundle ID), list its open windows.
      - Details: Optionally include window IDs, bounds (position and size), and whether a window is off-screen.
      - Multi-window apps: Clearly lists each window of the target app.
    - Server Status: Provides information about the Peekaboo MCP server itself (version, configured AI providers).

    Use Cases:
    - Agent needs to know if 'Photoshop' is running before attempting to automate it.
      { "item_type": "running_applications" } // Agent checks if 'Photoshop' is in the list.
    - Agent wants to find a specific 'Notes' window to capture.
      { "item_type": "application_windows", "app": "Notes", "include_window_details": ["ids", "bounds"] }
      The agent can then use the window title or ID with the 'image' tool.
    Peekaboo MCP 3.0.0-beta.2 using anthropic/claude-opus-4-20250514, ollama/llava:latest
    """

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "item_type": SchemaBuilder.string(
                    description: "Specifies the type of items to list. If omitted or empty, it defaults to 'application_windows' if 'app' is provided, otherwise 'running_applications'. Valid options are:\n- `running_applications`: Lists all currently running applications.\n- `application_windows`: Lists open windows for a specific application. Requires the `app` parameter.\n- `server_status`: Returns information about the Peekaboo MCP server.",
                    enum: ["running_applications", "application_windows", "server_status"]),
                "app": SchemaBuilder.string(
                    description: "Required when `item_type` is `application_windows`. Specifies the target application by its name (e.g., \"Safari\", \"TextEdit\"), bundle ID, or process ID (e.g., \"PID:663\"). Fuzzy matching is used for names, so partial names may work."),
                "include_window_details": SchemaBuilder.array(
                    items: SchemaBuilder.string(
                        enum: ["off_screen", "bounds", "ids"]),
                    description: "Optional, only applicable when `item_type` is `application_windows`. Specifies additional details to include for each window. Provide an array of strings. Example: [\"bounds\", \"ids\"].\n- `ids`: Include window ID.\n- `bounds`: Include window position and size (x, y, width, height).\n- `off_screen`: Indicate if the window is currently off-screen."),
            ],
            required: [])
    }

    public init() {}

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        // Determine item type
        let itemTypeString = arguments.getString("item_type")
        let app = arguments.getString("app")
        let includeWindowDetails = arguments.getStringArray("include_window_details")

        // Determine effective item type
        let effectiveItemType: ItemType = if let typeStr = itemTypeString {
            switch typeStr {
            case "running_applications":
                .runningApplications
            case "application_windows":
                .applicationWindows
            case "server_status":
                .serverStatus
            default:
                app != nil ? .applicationWindows : .runningApplications
            }
        } else {
            app != nil ? .applicationWindows : .runningApplications
        }

        // Validate parameters
        if effectiveItemType == .applicationWindows, app == nil {
            return ToolResponse.error("For 'application_windows', 'app' identifier is required.")
        }

        // Execute based on type
        switch effectiveItemType {
        case .runningApplications:
            return try await self.listRunningApplications()
        case .applicationWindows:
            return try await self.listApplicationWindows(app: app!, includeDetails: includeWindowDetails)
        case .serverStatus:
            return await self.getServerStatus()
        }
    }

    private func listRunningApplications() async throws -> ToolResponse {
        do {
            let output = try await PeekabooServices.shared.applications.listApplications()

            let apps = output.data.applications
            var summary = "Found \(apps.count) running application\(apps.count != 1 ? "s" : ""):\n\n"

            for (index, app) in apps.enumerated() {
                summary += "\(index + 1). \(app.name)"
                if let bundleID = app.bundleIdentifier, !bundleID.isEmpty {
                    summary += " (\(bundleID))"
                }
                summary += " - PID: \(app.processIdentifier)"
                if app.isActive {
                    summary += " [ACTIVE]"
                }
                summary += " - Windows: \(app.windowCount)\n"
            }

            return ToolResponse.text(summary)
        } catch {
            return ToolResponse.error("Failed to list applications: \(error.localizedDescription)")
        }
    }

    private func listApplicationWindows(app: String, includeDetails: [String]?) async throws -> ToolResponse {
        do {
            // Get windows for the app (the service handles identifier resolution)
            let output = try await PeekabooServices.shared.applications.listWindows(for: app, timeout: nil)

            let windows = output.data.windows
            let appInfo = output.data.targetApplication

            var summary: String
            if let appInfo {
                summary = "Found \(windows.count) window\(windows.count != 1 ? "s" : "") for application: \(appInfo.name)"

                if let bundleID = appInfo.bundleIdentifier, !bundleID.isEmpty {
                    summary += " (\(bundleID))"
                }
                summary += " - PID: \(appInfo.processIdentifier)\n\n"
            } else {
                summary = "Found \(windows.count) window\(windows.count != 1 ? "s" : "") for application: \(app)\n\n"
            }

            if !windows.isEmpty {
                summary += "Windows:\n"
                for (index, window) in windows.enumerated() {
                    summary += "\(index + 1). \"\(window.title)\""

                    // Add optional details
                    if let details = includeDetails {
                        if details.contains("ids"), window.windowID != 0 {
                            summary += " [ID: \(window.windowID)]"
                        }

                        if details.contains("off_screen") {
                            summary += window.isOffScreen ? " [OFF-SCREEN]" : " [ON-SCREEN]"
                        }

                        if details.contains("bounds") {
                            let bounds = window.bounds
                            summary += " [\(Int(bounds.origin.x)),\(Int(bounds.origin.y)) \(Int(bounds.width))×\(Int(bounds.height))]"
                        }
                    }

                    summary += "\n"
                }
            }

            return ToolResponse.text(summary)
        } catch {
            return ToolResponse.error("Failed to list windows: \(error.localizedDescription)")
        }
    }

    private func getServerStatus() async -> ToolResponse {
        var sections: [String] = []

        // 1. Server version
        sections.append("# Peekaboo MCP Server Status")
        sections.append("")
        sections.append("Version: 3.0.0-beta.2")
        sections.append("Platform: macOS")
        sections.append("")

        // 2. System Permissions
        sections.append("## System Permissions")

        let screenRecording = await PeekabooServices.shared.screenCapture.hasScreenRecordingPermission()
        let accessibility = await PeekabooServices.shared.automation.hasAccessibilityPermission()

        sections.append("- Screen Recording: \(screenRecording ? "✅ Granted" : "❌ Not granted")")
        sections.append("- Accessibility: \(accessibility ? "✅ Granted" : "❌ Not granted")")
        sections.append("")

        // 3. AI Provider Status
        sections.append("## AI Provider Status")

        if let providersString = ProcessInfo.processInfo.environment["PEEKABOO_AI_PROVIDERS"] {
            sections.append("Configured providers: \(providersString)")
        } else {
            sections.append("❌ No AI providers configured")
            sections.append("Configure PEEKABOO_AI_PROVIDERS environment variable to enable image analysis")
        }
        sections.append("")

        // 4. Configuration Issues
        sections.append("## Configuration Issues")

        var issues: [String] = []

        if !screenRecording {
            issues.append("❌ Screen Recording permission not granted")
        }

        if ProcessInfo.processInfo.environment["PEEKABOO_AI_PROVIDERS"] == nil {
            issues.append("⚠️  No AI providers configured (analysis features will be limited)")
        }

        if issues.isEmpty {
            sections.append("✅ No configuration issues detected")
        } else {
            for issue in issues {
                sections.append(issue)
            }
        }
        sections.append("")

        // 5. System Information
        sections.append("## System Information")
        sections.append("- Platform: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        sections.append("- Architecture: \(ProcessInfo.processInfo.processorArchitecture)")

        let fullStatus = sections.joined(separator: "\n")

        return ToolResponse.text(fullStatus)
    }
}

// Helper enum for item types
private enum ItemType {
    case runningApplications
    case applicationWindows
    case serverStatus
}

// Extension to get processor architecture
extension ProcessInfo {
    fileprivate var processorArchitecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}
