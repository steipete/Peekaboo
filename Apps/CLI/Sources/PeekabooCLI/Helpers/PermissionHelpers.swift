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

    /// Try to fetch permissions from the XPC helper; falls back to local services on failure.
    @MainActor
    private static func remotePermissionsStatus(serviceName override: String? = nil) async -> PermissionsStatus? {
        let envService = ProcessInfo.processInfo.environment["PEEKABOO_XPC_SERVICE"]
        let resolvedOverride = override ?? envService

        let candidates: [(String, PeekabooXPCHostKind)] = if let explicit = resolvedOverride {
            [(explicit, .helper)]
        } else {
            [
                (PeekabooXPCConstants.guiServiceName, .gui),
                (PeekabooXPCConstants.serviceName, .helper),
            ]
        }

        let identity = PeekabooXPCClientIdentity(
            bundleIdentifier: Bundle.main.bundleIdentifier,
            teamIdentifier: nil,
            processIdentifier: getpid(),
            hostname: Host.current().name
        )

        for (service, hostKind) in candidates {
            let client = PeekabooXPCClient(serviceName: service)
            do {
                let handshake = try await client.handshake(client: identity, requestedHost: hostKind)
                guard handshake.supportedOperations.contains(.permissionsStatus) else { continue }
                return try await client.permissionsStatus()
            } catch {
                continue
            }
        }
        return nil
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
            ? await self.remotePermissionsStatus(serviceName: serviceName)
            : nil

        let status: PermissionsStatus = if let remoteStatus {
            remoteStatus
        } else {
            await Task { @MainActor in services.permissions.checkAllPermissions() }.value
        }

        let permissionList = [
            PermissionInfo(
                name: "Screen Recording",
                isRequired: true,
                isGranted: status.screenRecording,
                grantInstructions: "System Settings > Privacy & Security > Screen Recording"
            ),
            PermissionInfo(
                name: "Accessibility",
                isRequired: true,
                isGranted: status.accessibility,
                grantInstructions: "System Settings > Privacy & Security > Accessibility"
            ),
            PermissionInfo(
                name: "AppleScript (Automation)",
                isRequired: true,
                isGranted: status.appleScript,
                grantInstructions: "System Settings > Privacy & Security > Automation (enable Peekaboo)"
            )
        ]

        let source = remoteStatus != nil ? "xpc" : "local"
        return PermissionStatusResponse(source: source, permissions: permissionList)
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
