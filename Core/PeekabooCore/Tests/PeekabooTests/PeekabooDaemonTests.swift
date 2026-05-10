import Foundation
import PeekabooBridge
import PeekabooCore
import Testing

@Suite(.tags(.safe))
@MainActor
struct PeekabooDaemonTests {
    @Test
    func `auto daemon reports activity and idle deadline`() async {
        let daemon = PeekabooDaemon(configuration: .init(
            mode: .auto,
            bridgeSocketPath: "/tmp/peekaboo-test.sock",
            allowlistedTeams: [],
            windowTrackingEnabled: false,
            hostKind: .onDemand,
            idleTimeout: 10))

        await daemon.recordActivityStart(operation: .listApplications)
        var status = await daemon.daemonStatus()
        #expect(status.mode == .auto)
        #expect(status.activity?.activeRequests == 1)
        #expect(status.activity?.idleExitAt == nil)

        await daemon.recordActivityEnd(operation: .listApplications)
        status = await daemon.daemonStatus()
        #expect(status.activity?.activeRequests == 0)
        #expect(status.activity?.idleTimeoutSeconds == 10)
        #expect(status.activity?.idleExitAt != nil)

        _ = await daemon.requestStop()
    }
}
