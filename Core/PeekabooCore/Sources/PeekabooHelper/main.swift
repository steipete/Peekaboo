import Foundation
import PeekabooCore
import PeekabooXPC

@main
struct PeekabooHelperMain {
    static func main() {
        let services = PeekabooServices()

        let allowlistedBundles: Set<String> = [
            "boo.peekaboo.peekaboo", // CLI
            "boo.peekaboo.mac", // GUI app
        ]

        let allowlistedTeams: Set<String> = [
            "Y5PE65HELJ",
        ]

        let host = PeekabooXPCBootstrap.startHelperListener(
            services: services,
            serviceName: PeekabooXPCConstants.serviceName,
            allowlistedTeams: allowlistedTeams,
            allowlistedBundles: allowlistedBundles,
            allowedOperations: PeekabooXPCOperation.remoteDefaultAllowlist)

        host.resume()
        dispatchMain()
    }
}
