import Foundation
import PeekabooAgentRuntime

@MainActor
public enum PeekabooXPCBootstrap {
    /// Start a mach service listener for the helper or GUI host.
    @discardableResult
    public static func startHelperListener(
        services: any PeekabooServiceProviding,
        serviceName: String = PeekabooXPCConstants.serviceName,
        allowlistedTeams: Set<String>,
        allowlistedBundles: Set<String>,
        allowedOperations: Set<PeekabooXPCOperation> = PeekabooXPCOperation.remoteDefaultAllowlist) -> PeekabooXPCHost
    {
        let server = PeekabooXPCServer(
            services: services,
            allowlistedTeams: allowlistedTeams,
            allowlistedBundles: allowlistedBundles,
            allowedOperations: allowedOperations)
        let host = PeekabooXPCHost.machService(name: serviceName, server: server)
        host.resume()
        return host
    }

    /// Start an anonymous listener for in-process embedding (e.g., Peekaboo.app).
    @discardableResult
    public static func startEmbeddedListener(
        services: any PeekabooServiceProviding,
        allowlistedTeams: Set<String>,
        allowlistedBundles: Set<String>,
        allowedOperations: Set<PeekabooXPCOperation> = PeekabooXPCOperation.remoteDefaultAllowlist) -> PeekabooXPCHost
    {
        let server = PeekabooXPCServer(
            services: services,
            allowlistedTeams: allowlistedTeams,
            allowlistedBundles: allowlistedBundles,
            allowedOperations: allowedOperations)
        let host = PeekabooXPCHost.embedded(server: server)
        host.resume()
        return host
    }
}
