import Foundation
import PeekabooAutomationKit
import PeekabooFoundation

@MainActor
extension PeekabooBridgeServer {
    static func invalidRequest(for request: PeekabooBridgeRequest) -> PeekabooBridgeErrorEnvelope {
        PeekabooBridgeErrorEnvelope(
            code: .invalidRequest,
            message: "Unexpected request for operation \(request.operation.rawValue)")
    }

    func handleHandshake(
        _ payload: PeekabooBridgeHandshake,
        peer: PeekabooBridgePeer?) throws -> PeekabooBridgeResponse
    {
        let resolvedBundle = peer?.bundleIdentifier ?? payload.client.bundleIdentifier
        let resolvedTeam = peer?.teamIdentifier ?? payload.client.teamIdentifier

        guard self.supportedVersions.contains(payload.protocolVersion) else {
            throw PeekabooBridgeErrorEnvelope(
                code: .versionMismatch,
                message: "Protocol \(payload.protocolVersion.major).\(payload.protocolVersion.minor) is not supported")
        }

        if let bundle = resolvedBundle,
           !self.allowlistedBundles.isEmpty,
           !self.allowlistedBundles.contains(bundle)
        {
            throw PeekabooBridgeErrorEnvelope(code: .unauthorizedClient, message: "Bundle \(bundle) is not authorized")
        }

        if let team = resolvedTeam,
           !self.allowlistedTeams.isEmpty,
           !self.allowlistedTeams.contains(team)
        {
            throw PeekabooBridgeErrorEnvelope(code: .unauthorizedClient, message: "Team \(team) is not authorized")
        }

        if let uid = peer?.userIdentifier, uid != getuid() {
            throw PeekabooBridgeErrorEnvelope(
                code: .unauthorizedClient,
                message: "UID \(uid) is not authorized for this listener")
        }

        if let pid = peer?.processIdentifier {
            let bundleDescription = resolvedBundle ?? "<unknown>"
            self.logger
                .debug(
                    "bridge handshake ok pid=\(pid, privacy: .public) bundle=\(bundleDescription, privacy: .public)")
        }

        let negotiated = min(
            max(payload.protocolVersion, self.supportedVersions.lowerBound),
            self.supportedVersions.upperBound)

        let permissions = self.currentPermissions(allowAppleScriptLaunch: false)
        let advertisedOps = Array(self.operationsCompatibleWithNegotiatedVersion(
            self.allowedOperationsToAdvertise(),
            negotiated)).sorted { $0.rawValue < $1.rawValue }
        let enabledOps = self.operationsCompatibleWithNegotiatedVersion(
            self.effectiveAllowedOperations(permissions: permissions),
            negotiated)
        let permissionTags = Dictionary(
            uniqueKeysWithValues: advertisedOps.map { op in
                (op.rawValue, Array(op.requiredPermissions).sorted { $0.rawValue < $1.rawValue })
            })

        self.logger.debug(
            """
            Handshake advertised=\(advertisedOps.count, privacy: .public) \
            enabled=\(enabledOps.count, privacy: .public) \
            tags=\(permissionTags.count, privacy: .public)
            """)

        let response = PeekabooBridgeHandshakeResponse(
            negotiatedVersion: negotiated,
            hostKind: self.hostKind,
            build: PeekabooBridgeConstants.buildIdentifier,
            supportedOperations: advertisedOps,
            permissions: permissions,
            enabledOperations: Array(enabledOps).sorted { $0.rawValue < $1.rawValue },
            permissionTags: permissionTags)
        return .handshake(response)
    }

    func operationsCompatibleWithNegotiatedVersion(
        _ operations: Set<PeekabooBridgeOperation>,
        _ negotiated: PeekabooBridgeProtocolVersion) -> Set<PeekabooBridgeOperation>
    {
        var compatible = operations
        if negotiated < PeekabooBridgeProtocolVersion(major: 1, minor: 1) {
            compatible.remove(.targetedHotkey)
        }
        if negotiated < PeekabooBridgeProtocolVersion(major: 1, minor: 2) {
            compatible.remove(.requestPostEventPermission)
        }
        return compatible
    }

    func allowedOperationsToAdvertise() -> Set<PeekabooBridgeOperation> {
        var operations = self.allowedOperations
        if self.daemonControl == nil {
            operations.remove(.daemonStatus)
            operations.remove(.daemonStop)
        }
        if (self.services.automation as? any TargetedHotkeyServiceProtocol)?.supportsTargetedHotkeys != true {
            operations.remove(.targetedHotkey)
        }
        return operations
    }

    func effectiveAllowedOperations(permissions: PermissionsStatus) -> Set<PeekabooBridgeOperation> {
        let granted = Self.grantedPermissions(from: permissions)

        return Set(
            self.allowedOperationsToAdvertise().filter { operation in
                operation.requiredPermissions.isSubset(of: granted)
            })
    }

    static func grantedPermissions(from permissions: PermissionsStatus) -> Set<PeekabooBridgePermissionKind> {
        var granted: Set<PeekabooBridgePermissionKind> = []
        if permissions.screenRecording {
            granted.insert(.screenRecording)
        }
        if permissions.accessibility {
            granted.insert(.accessibility)
        }
        if permissions.appleScript {
            granted.insert(.appleScript)
        }
        if permissions.postEvent {
            granted.insert(.postEvent)
        }

        return granted
    }

    func currentPermissions(allowAppleScriptLaunch: Bool = true) -> PermissionsStatus {
        self.permissionStatusEvaluator(allowAppleScriptLaunch)
            .withPostEvent(self.postEventAccessEvaluator())
    }

    static func bridgePermission(for error: PeekabooError) -> PeekabooBridgePermissionKind? {
        switch error {
        case .permissionDeniedAccessibility:
            .accessibility
        case .permissionDeniedScreenRecording:
            .screenRecording
        case .permissionDeniedEventSynthesizing:
            .postEvent
        default:
            nil
        }
    }
}
