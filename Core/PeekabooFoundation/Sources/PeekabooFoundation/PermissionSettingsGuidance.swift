import Foundation

/// System Settings paths for macOS permissions, using the row names on the specified OS version.
public enum PermissionSettingsGuidance {
    public enum Permission: Sendable {
        case screenRecording
        case accessibility
        case eventSynthesizing
    }

    public static func path(
        for permission: Permission,
        on version: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion) -> String
    {
        let row: String = switch permission {
        case .screenRecording:
            version.majorVersion >= 15 ? "Screen & System Audio Recording" : "Screen Recording"
        case .accessibility, .eventSynthesizing:
            // Event Synthesizing has a separate TCC check but shares Accessibility's Settings list.
            version.majorVersion >= 27 ? "Device Control and Data Access" : "Accessibility"
        }
        return "System Settings > Privacy & Security > \(row)"
    }
}
