import Foundation
import PeekabooCore
import PeekabooXPC

/// Shared permission checking and formatting utilities
enum PermissionHelpers {
    struct PermissionInfo: Codable {
        let name: String
        let isRequired: Bool
        let isGranted: Bool
        let grantInstructions: String
    }

    struct PermissionStatusResponse: Codable {
        let source: String
        let permissions: [PermissionInfo]
    }

    private static let defaultServiceName = PeekabooXPCConstants.serviceName

    /// Try to fetch permissions from the XPC helper; falls back to local services on failure.
    @MainActor
    private static func remotePermissionsStatus(
        serviceName: String = ProcessInfo.processInfo.environment["PEEKABOO_XPC_SERVICE"] ?? defaultServiceName
    ) async -> PermissionsStatus? {
        let client = PeekabooXPCClient(serviceName: serviceName)
        let identity = PeekabooXPCClientIdentity(
            bundleIdentifier: Bundle.main.bundleIdentifier,
            teamIdentifier: nil,
            processIdentifier: getpid(),
            hostname: Host.current().name
        )

        do {
            let handshake = try await client.handshake(client: identity, requestedHost: .helper)
            guard handshake.supportedOperations.contains(.permissionsStatus) else { return nil }
            return try await client.permissionsStatus()
        } catch {
            return nil
        }
    }

    /// Get current permission status for all Peekaboo permissions
    static func getCurrentPermissions(
        services: any PeekabooServiceProviding,
        allowRemote: Bool = true,
        serviceName: String? = nil
    ) async -> [PermissionInfo] {
        let response = await self.getCurrentPermissionsWithSource(
            services: services,
            allowRemote: allowRemote,
            serviceName: serviceName
        )
        return response.permissions
    }

    /// Get current permission status along with whether a remote helper responded.
    static func getCurrentPermissionsWithSource(
        services: any PeekabooServiceProviding,
        allowRemote: Bool = true,
        serviceName: String? = nil
    ) async -> PermissionStatusResponse {
        // Prefer remote helper when available so SSH/sandboxed shells can reuse existing TCC grants.
        let remoteStatus = allowRemote
            ? await self.remotePermissionsStatus(serviceName: serviceName ?? self.defaultServiceName)
            : nil

        let screenRecording: Bool
        let accessibility: Bool

        if let remoteStatus {
            screenRecording = remoteStatus.screenRecording
            accessibility = remoteStatus.accessibility
        } else {
            screenRecording = await Task { @MainActor in
                await services.screenCapture.hasScreenRecordingPermission()
            }.value
            accessibility = await AutomationServiceBridge.hasAccessibilityPermission(automation: services.automation)
        }

        let permissions = [
            PermissionInfo(
                name: "Screen Recording",
                isRequired: true,
                isGranted: screenRecording,
                grantInstructions: "System Settings > Privacy & Security > Screen Recording"
            ),
            PermissionInfo(
                name: "Accessibility",
                isRequired: false,
                isGranted: accessibility,
                grantInstructions: "System Settings > Privacy & Security > Accessibility"
            )
        ]

        let source = remoteStatus != nil ? "xpc" : "local"
        return PermissionStatusResponse(source: source, permissions: permissions)
    }

    /// Format permission status for display
    static func formatPermissionStatus(_ permission: PermissionInfo) -> String {
        // Format permission status for display
        let status = permission.isGranted ? "Granted" : "Not Granted"
        let requirement = permission.isRequired ? "Required" : "Optional"
        return "\(permission.name) (\(requirement)): \(status)"
    }

    /// Format permissions for help display with dynamic status
    static func formatPermissionsForHelp(
        services: any PeekabooServiceProviding) async -> String {
        // Format permissions for help display with dynamic status
        let permissions = await self.getCurrentPermissions(services: services)
        var output = ["PERMISSIONS:"]

        for permission in permissions {
            output.append("  \(self.formatPermissionStatus(permission))")

            // Only show grant instructions if permission is not granted
            if !permission.isGranted {
                output.append("    Grant via: \(permission.grantInstructions)")
            }
        }

        output.append("")
        output.append("Check detailed permission status:")
        output.append("  peekaboo permissions")

        return output.joined(separator: "\n")
    }
}
