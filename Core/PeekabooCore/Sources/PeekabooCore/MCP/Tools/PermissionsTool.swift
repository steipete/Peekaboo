import Foundation
import MCP

/// MCP tool for checking macOS system permissions
public struct PermissionsTool: MCPTool {
    public let name = "permissions"
    public let description = """
    Check macOS system permissions required for automation.
    Verifies both Screen Recording and Accessibility permissions.
    Returns the current permission status for each required permission.
    Peekaboo MCP 3.0.0-beta.2 using anthropic/claude-opus-4-20250514, ollama/llava:latest
    """

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [:],
            required: [])
    }

    public init() {}

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        // Get permissions from PeekabooCore services
        let screenRecording = await PeekabooServices.shared.screenCapture.hasScreenRecordingPermission()
        let accessibility = await PeekabooServices.shared.automation.hasAccessibilityPermission()

        // Build response text
        var lines: [String] = []
        lines.append("macOS Permissions Status:")
        lines.append("")
        lines.append("Screen Recording: \(screenRecording ? "✅ Granted" : "❌ Not Granted")")
        lines.append("Accessibility: \(accessibility ? "✅ Granted" : "⚠️  Not Granted (Optional)")")

        if !screenRecording {
            lines.append("")
            lines.append("⚠️  Screen Recording permission is REQUIRED for capturing screenshots.")
            lines.append("Grant via: System Settings > Privacy & Security > Screen Recording")
        }

        if !accessibility {
            lines.append("")
            lines.append("ℹ️  Accessibility permission is optional but needed for UI automation.")
            lines.append("Grant via: System Settings > Privacy & Security > Accessibility")
        }

        let responseText = lines.joined(separator: "\n")

        // Return error response if required permissions are missing
        if !screenRecording {
            return ToolResponse.error(responseText)
        }

        return ToolResponse.text(responseText)
    }
}
