//
import Foundation
import PeekabooCore
import PeekabooXPC

private var serviceDelegate: PeekabooXPCListenerDelegate?
private var serviceListener: NSXPCListener?

Task { @MainActor in
    let services = PeekabooServices()

    let allowlistedBundles: Set<String> = [
        "boo.peekaboo", // CLI (Developer ID build)
        "boo.peekaboo.peekaboo", // CLI (release bundle id)
        "boo.peekaboo.mac", // GUI app
    ]

    let allowlistedTeams: Set<String> = [
        "Y5PE65HELJ",
    ]

    let server = PeekabooXPCServer(
        services: services,
        allowlistedTeams: allowlistedTeams,
        allowlistedBundles: allowlistedBundles)

    let listener = NSXPCListener.service()
    let delegate = PeekabooXPCListenerDelegate(server: server)
    listener.delegate = delegate
    listener.resume()

    serviceDelegate = delegate
    serviceListener = listener
}

dispatchMain()
