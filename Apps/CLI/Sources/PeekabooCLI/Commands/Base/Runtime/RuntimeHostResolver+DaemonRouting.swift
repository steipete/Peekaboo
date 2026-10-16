import PeekabooBridge

extension RuntimeHostResolver {
    enum DaemonOccupancy {
        case absent
        case present
        case untrusted
    }

    static func implicitDaemonOccupancy(
        socketPath: String,
        context: RemoteResolutionContext,
        releaseSigned: Bool,
        rejections: inout [String]
    ) async throws -> DaemonOccupancy {
        do {
            return try await context.fetchDaemonStatus(socketPath) == nil ? .absent : .present
        } catch let error as PeekabooBridgeErrorEnvelope
            where !releaseSigned && error.isLocalHostAuthenticationFailure {
            // Rejected identity proves neither absence nor permission to replace this listener.
            rejections.append("untrusted host via \(socketPath)")
            return .untrusted
        }
    }

    static func startImplicitDaemon(
        socketPath: String,
        context: RemoteResolutionContext,
        releaseSigned: Bool,
        rejections: inout [String]
    ) async throws -> String? {
        do {
            return try await context.startOnDemandDaemon(socketPath, context.environment)
        } catch let error as PeekabooBridgeErrorEnvelope
            where !releaseSigned && error.isLocalHostAuthenticationFailure {
            // The listener may change between candidate evaluation, occupancy, and startup.
            rejections.append("untrusted host via \(socketPath)")
            return nil
        }
    }

    static func resolveNewImplicitDaemon(
        context: RemoteResolutionContext,
        exactBuildSocketPath: String? = nil,
        autoStartAllowed: Bool,
        releaseSigned: Bool,
        rejections: inout [String],
        recordRejection: (RemoteCandidateEvaluation) -> Void
    ) async throws -> Resolution? {
        // Exact-build routing probes occupancy even when auto-start is disabled.
        var exactOccupancy: DaemonOccupancy?
        if let exactBuildSocketPath {
            exactOccupancy = try await self.implicitDaemonOccupancy(
                socketPath: exactBuildSocketPath,
                context: context,
                releaseSigned: releaseSigned,
                rejections: &rejections
            )
            guard exactOccupancy == .absent else { return nil }
        }
        guard autoStartAllowed,
              try await !self.shouldSkipOnDemandDaemon(context: context)
        else { return nil }
        let occupancy: DaemonOccupancy = if let exactOccupancy {
            exactOccupancy
        } else {
            try await self.implicitDaemonOccupancy(
                socketPath: context.candidatePlan.daemonSocketPath,
                context: context,
                releaseSigned: releaseSigned,
                rejections: &rejections
            )
        }
        guard occupancy != .untrusted else { return nil }
        let socketPath = exactBuildSocketPath ?? DaemonLaunchPolicy.autoStartSocketPath(
            daemonSocketPath: context.candidatePlan.daemonSocketPath,
            defaultSocketWasOccupiedAndRejected: occupancy != .absent,
            runtimeBuildIdentity: context.candidatePlan.runtimeBuildIdentity
        )
        guard let resolvedSocket = try await self.startImplicitDaemon(
            socketPath: socketPath,
            context: context,
            releaseSigned: releaseSigned,
            rejections: &rejections
        ) else { return nil }
        return try await context.resolveRemoteServices(
            candidates: [ImplicitRemoteCandidate(
                socketPath: resolvedSocket,
                requireReusableDaemon: true,
                requiredHostKind: exactBuildSocketPath == nil ? nil : .onDemand,
                requiresValidatedHistoricalDaemon: false
            )],
            requiredProtocolVersion: exactBuildSocketPath == nil ? nil : PeekabooBridgeConstants.protocolVersion,
            permissionRejections: &rejections,
            recordRejection: recordRejection
        )
    }
}
