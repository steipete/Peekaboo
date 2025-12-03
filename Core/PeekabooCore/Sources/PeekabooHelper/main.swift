import Foundation
import PeekabooCore
import PeekabooXPC

@main
@MainActor
struct PeekabooHelperMain {
    private static var xpcHost: PeekabooXPCHost?

    static func main() {
        let services = PeekabooServices()

        let allowlistedBundles: Set<String> = [
            "boo.peekaboo", // CLI (Developer ID build)
            "boo.peekaboo.peekaboo", // CLI (signed bundle id in release)
            "boo.peekaboo.mac", // GUI app
        ]

        let allowlistedTeams: Set<String> = [
            "Y5PE65HELJ",
        ]

        self.xpcHost = PeekabooXPCBootstrap.startHelperListener(
            services: services,
            serviceName: PeekabooXPCConstants.serviceName,
            allowlistedTeams: allowlistedTeams,
            allowlistedBundles: allowlistedBundles,
            allowedOperations: PeekabooXPCOperation.remoteDefaultAllowlist)

        dispatchMain()
    }
}
