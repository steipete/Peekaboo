import Darwin
import Foundation
import PeekabooAutomationKit
import PeekabooBridge
import PeekabooCore

extension RuntimeHostResolver {
    /// Reuses fully authenticated handshakes only within one runtime-resolution attempt.
    /// Candidate requirements are reapplied before selection, and the retained client keeps the
    /// listener identity and operation session that every later request revalidates before writing.
    @MainActor
    final class RemoteHandshakeCache {
        struct Entry {
            let client: PeekabooBridgeClient
            let response: PeekabooBridgeHandshakeResponse
        }

        let identity: PeekabooBridgeClientIdentity
        let trustedHostTeamIDs: Set<String>?
        let clientFactory: (@MainActor (String) -> PeekabooBridgeClient)?
        let handshakeProvider: ScreenCaptureKitHandshake?
        private var entriesBySocketPath: [String: Entry] = [:]
        private var failuresBySocketPath: [String: any Error] = [:]

        convenience init() {
            self.init(identity: PeekabooBridgeClientIdentity(
                bundleIdentifier: Bundle.main.bundleIdentifier,
                teamIdentifier: nil,
                processIdentifier: getpid(),
                hostname: Host.current().name
            ))
        }

        init(
            identity: PeekabooBridgeClientIdentity,
            trustedHostTeamIDs: Set<String>? = nil,
            clientFactory: (@MainActor (String) -> PeekabooBridgeClient)? = nil,
            handshakeProvider: ScreenCaptureKitHandshake? = nil
        ) {
            self.identity = identity
            self.trustedHostTeamIDs = trustedHostTeamIDs
            self.clientFactory = clientFactory
            self.handshakeProvider = handshakeProvider
        }

        func handshake(
            _ candidate: ImplicitRemoteCandidate,
            identity: PeekabooBridgeClientIdentity
        ) async throws -> Entry {
            guard self.isBound(to: identity) else {
                throw POSIXError(.EINVAL)
            }
            let socketPath = Self.standardizedSocketPath(candidate.socketPath)
            if let entry = self.entriesBySocketPath[socketPath] {
                return entry
            }
            if let failure = self.failuresBySocketPath[socketPath] {
                throw failure
            }

            let client = self.clientFactory?(candidate.socketPath) ?? PeekabooBridgeClient(
                socketPath: candidate.socketPath,
                trustedHostTeamIDs: self.trustedHostTeamIDs
            )
            let response: PeekabooBridgeHandshakeResponse
            do {
                response = if let handshakeProvider {
                    try await handshakeProvider(candidate, self.identity)
                } else {
                    try await client.handshake(client: self.identity, requestedHost: nil)
                }
            } catch {
                try Task.checkCancellation()
                // A missing daemon can appear after auto-start; only cache GUI failures.
                if candidate.requiredHostKind == .gui {
                    self.failuresBySocketPath[socketPath] = error
                }
                throw error
            }
            let entry = Entry(client: client, response: response)
            self.entriesBySocketPath[socketPath] = entry
            return entry
        }

        func entry(
            for candidate: ImplicitRemoteCandidate,
            identity: PeekabooBridgeClientIdentity
        ) -> Entry? {
            guard self.isBound(to: identity) else { return nil }
            return self.entriesBySocketPath[Self.standardizedSocketPath(candidate.socketPath)]
        }

        private func isBound(to identity: PeekabooBridgeClientIdentity) -> Bool {
            self.identity.bundleIdentifier == identity.bundleIdentifier &&
                self.identity.teamIdentifier == identity.teamIdentifier &&
                self.identity.processIdentifier == identity.processIdentifier &&
                self.identity.hostname == identity.hostname
        }

        private static func standardizedSocketPath(_ socketPath: String) -> String {
            NSString(string: socketPath).standardizingPath
        }
    }

    struct ImplicitRemoteCandidate: Equatable, Sendable {
        let socketPath: String
        let requireReusableDaemon: Bool
        let requiredHostKind: PeekabooBridgeHostKind?
        let requiresValidatedHistoricalDaemon: Bool
    }

    struct RemoteCandidatePlan {
        let explicitSocket: String?
        let daemonSocketPath: String
        let runtimeBuildIdentity: String
        let buildScopedDaemonSocketPath: String?
        let historicalBuildScopedDaemonSocketPaths: [String]
        let candidates: [ImplicitRemoteCandidate]
    }

    struct RemoteCandidateValidation {
        let reusableDaemonStatus: PeekabooDaemonStatus?
    }

    enum RemoteCandidateRejection: Equatable {
        case protocolVersionMismatch
        case hostKindMismatch(expected: PeekabooBridgeHostKind)
        case missingPermissions(Set<PeekabooBridgePermissionKind>)
        case requirementsNotMet
        case reusableDaemonUnavailable
        case historicalDaemonInvalid
        case reusableDaemonIdentityUnavailable
    }

    struct RemoteCandidateEvaluation {
        let validation: RemoteCandidateValidation?
        let rejection: RemoteCandidateRejection?
        let requirementFailure: BridgeCapabilityPolicy.RemoteRequirementFailure?

        static func accepted(_ validation: RemoteCandidateValidation) -> Self {
            Self(validation: validation, rejection: nil, requirementFailure: nil)
        }

        static func rejected(
            _ rejection: RemoteCandidateRejection,
            requirementFailure: BridgeCapabilityPolicy.RemoteRequirementFailure? = nil
        ) -> Self {
            Self(validation: nil, rejection: rejection, requirementFailure: requirementFailure)
        }
    }

    enum InitialRoutingDecision: Equatable {
        case local(snapshotInvalidationRemoteSocketPaths: [String])
        case remote
    }

    struct Resolution {
        let services: any PeekabooServiceProviding
        let hostDescription: String
        let selectedRemoteSocketPath: String?
        let selectedRemoteHostProcessIdentifier: pid_t?
        var selectedRemoteHostIdentity: PeekabooBridgeHostIdentity?
        var selectedRemoteAuthenticatedHostIdentity: PeekabooBridgeAuthenticatedHostIdentity?
        var selectedRemoteAuthenticatedHostIdentityProvider:
            (@Sendable () async -> PeekabooBridgeAuthenticatedHostIdentity?)?
        let snapshotInvalidationRemoteSocketPaths: [String]
        let applicationRelaunchAllowed: Bool
        let requiredHostFailure: String?
        var captureEngineSafetyOverride: CaptureEnginePreference?
        var toolCapturePreflightRefusal: MCPToolCapturePreflightRefusal?
    }
}

extension RuntimeHostResolver {
    static func shouldSkipOnDemandDaemon(context: RemoteResolutionContext) async throws -> Bool {
        guard context.candidatePlan.explicitSocket == nil,
              context.options.explicitSnapshotID == nil,
              context.preferredScreenCaptureKitOwner == nil,
              !context.options.requiresSurvivingApplicationHost,
              !context.options.requiresApplicationRelaunch,
              let gui = context.candidatePlan.candidates.first(where: { $0.requiredHostKind == .gui }),
              let callerPermissions = context.callerPermissionPreflight()
        else { return false }
        guard !callerPermissions.screenRecording || !callerPermissions.accessibility ||
            (callerPermissions.reportsPostEvent && !callerPermissions.postEvent)
        else { return false }

        do {
            let handshake = try await context.handshakeCache.handshake(gui, identity: context.identity).response
            // A child daemon inherits this caller's responsible-app TCC grants. Only skip
            // startup if the existing GUI both dominates those grants and can serve this command.
            guard handshake.hostKind == .gui,
                  self.permissionsAreProvablyWeaker(callerPermissions, than: handshake.permissions)
            else { return false }
            var permissionRejections: [String] = []
            return try await context.resolveRemoteServices(
                candidates: [gui],
                permissionRejections: &permissionRejections
            ) != nil
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            return false
        }
    }

    /// Unknown grants and opposing grants preserve daemon-first ordering.
    static func daemonIsProvablyWeaker(
        _ daemon: PeekabooBridgeHandshakeResponse,
        than gui: PeekabooBridgeHandshakeResponse
    ) -> Bool {
        guard daemon.hostKind == .onDemand, gui.hostKind == .gui else { return false }
        return self.permissionsAreProvablyWeaker(daemon.permissions, than: gui.permissions)
    }

    static func permissionsAreProvablyWeaker(
        _ permissions: PermissionsStatus?,
        than other: PermissionsStatus?
    ) -> Bool {
        guard let daemonPermissions = permissions, let guiPermissions = other
        else { return false }
        var grants = [
            (daemonPermissions.screenRecording, guiPermissions.screenRecording),
            (daemonPermissions.accessibility, guiPermissions.accessibility),
        ]
        if daemonPermissions.reportsPostEvent, guiPermissions.reportsPostEvent {
            grants.append((daemonPermissions.postEvent, guiPermissions.postEvent))
        }
        return grants.contains { !$0.0 && $0.1 } && !grants.contains { $0.0 && !$0.1 }
    }

    static func evaluateRemoteCandidate(
        _ candidate: ImplicitRemoteCandidate,
        handshake: PeekabooBridgeHandshakeResponse,
        options: CommandRuntimeOptions,
        requiredProtocolVersion: PeekabooBridgeProtocolVersion? = nil,
        fetchReusableDaemonStatus: (String) async -> PeekabooDaemonStatus? = { socketPath in
            try? await DaemonControlClient(socketPath: socketPath).fetchReusableDaemonStatus()
        }
    ) async -> RemoteCandidateEvaluation {
        guard requiredProtocolVersion == nil || handshake.negotiatedVersion == requiredProtocolVersion else {
            return .rejected(.protocolVersionMismatch)
        }
        if let requiredHostKind = candidate.requiredHostKind,
           handshake.hostKind != requiredHostKind {
            return .rejected(.hostKindMismatch(expected: requiredHostKind))
        }
        let missingPermissions = BridgeCapabilityPolicy.explicitlyMissingRemotePermissions(
            for: handshake,
            options: options
        )
        guard missingPermissions.isEmpty else {
            return .rejected(.missingPermissions(missingPermissions))
        }
        if let failure = BridgeCapabilityPolicy.firstUnmetRemoteRequirement(for: handshake, options: options) {
            return .rejected(.requirementsNotMet, requirementFailure: failure)
        }

        let requiresReusableHost = candidate.requireReusableDaemon ||
            options.requiresApplicationRelaunch ||
            options.requiresSurvivingApplicationHost
        let reusableDaemonStatus: PeekabooDaemonStatus? = if requiresReusableHost {
            await fetchReusableDaemonStatus(candidate.socketPath)
        } else {
            nil
        }
        guard !requiresReusableHost || reusableDaemonStatus != nil else {
            return .rejected(.reusableDaemonUnavailable)
        }

        if candidate.requiresValidatedHistoricalDaemon {
            guard let reusableDaemonStatus,
                  DaemonControlResolver.isValidatedHistoricalTarget(
                      status: reusableDaemonStatus,
                      socketPath: candidate.socketPath
                  ),
                  DaemonControlPlanner.supportsCurrentDaemon(reusableDaemonStatus)
            else {
                return .rejected(.historicalDaemonInvalid)
            }
        }
        if options.requiresApplicationRelaunch || options.requiresSurvivingApplicationHost,
           reusableDaemonStatus?.pid == nil {
            return .rejected(.reusableDaemonIdentityUnavailable)
        }
        return .accepted(RemoteCandidateValidation(reusableDaemonStatus: reusableDaemonStatus))
    }
}
