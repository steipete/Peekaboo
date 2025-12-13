import Foundation
import PeekabooAgentRuntime

@MainActor
public enum PeekabooBridgeBootstrap {
    @discardableResult
    public static func startHost(
        services: any PeekabooServiceProviding,
        hostKind: PeekabooBridgeHostKind,
        socketPath: String,
        allowlistedTeams: Set<String>,
        allowlistedBundles: Set<String>,
        allowedOperations: Set<PeekabooBridgeOperation> = PeekabooBridgeOperation.remoteDefaultAllowlist,
        maxMessageBytes: Int = 64 * 1024 * 1024,
        requestTimeoutSec: TimeInterval = 10) -> PeekabooBridgeHost
    {
        let server = PeekabooBridgeServer(
            services: services,
            hostKind: hostKind,
            allowlistedTeams: allowlistedTeams,
            allowlistedBundles: allowlistedBundles,
            allowedOperations: allowedOperations)

        let host = PeekabooBridgeHost(
            socketPath: socketPath,
            server: server,
            maxMessageBytes: maxMessageBytes,
            allowedTeamIDs: allowlistedTeams,
            requestTimeoutSec: requestTimeoutSec)

        Task {
            await host.start()
        }
        return host
    }
}
