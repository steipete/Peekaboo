import Darwin
import Foundation
import PeekabooBridgeTestSupport
import Testing
@testable import PeekabooBridge
@testable import PeekabooCLI

@MainActor
struct BridgeStatusUnsignedDaemonTests {
    @Test
    func `bridge status displays locally determined developer trust`() throws {
        var handshake = BridgeTestFixtures.handshake(
            negotiatedVersion: .init(
                major: 1,
                minor: 28
            ),
            hostKind: .onDemand,
            supportedOperations: []
        )
        handshake.trustMode = .unsignedSameBinaryDeveloperOptIn
        let report = BridgeHandshakeReport(from: handshake)
        let selected = BridgeSelectionReport.remote(
            socketPath: "/fixture/daemon.sock",
            handshake: report
        )
        #expect(selected.humanSummary.contains("trust: unsigned same-binary developer opt-in"))
        let encoded = try JSONEncoder().encode(report)
        #expect(String(data: encoded, encoding: .utf8)?.contains("unsignedSameBinaryDeveloperOptIn") == true)
    }

    @Test
    func `daemon status copies authenticated developer trust into JSON`() async throws {
        var advertisedStatus = PeekabooDaemonStatus(running: true, pid: getpid(), mode: .manual)
        advertisedStatus.trustMode = .releaseSignature
        let peer = try ScriptedBridgePeer(responses: [
            .handshake(BridgeTestFixtures.handshake(
                negotiatedVersion: .init(
                    major: 1,
                    minor: 28
                ),
                hostKind: .onDemand,
                supportedOperations: [.daemonStatus]
            )),
            .daemonStatus(advertisedStatus),
        ])
        let client = PeekabooBridgeClient(
            socketPath: peer.socketPath,
            trustedHostTeamIDs: nil,
            hostAuthentication: .init(
                signingIdentity: { _ in nil },
                currentProcessIsReleaseSigned: { false },
                unsignedDaemonPolicy: .init(
                    environment: ["PEEKABOO_ALLOW_UNSIGNED_DAEMON": "1"],
                    currentProcessIsReleaseSigned: { false }
                )
            )
        )
        do {
            let status = try #require(try await DaemonControlClient(socketPath: peer.socketPath)
                .fetchStatus(using: client))
            #expect(status.trustMode == .unsignedSameBinaryDeveloperOptIn)
            let encoded = try JSONEncoder().encode(status)
            #expect(String(data: encoded, encoding: .utf8)?.contains("unsignedSameBinaryDeveloperOptIn") == true)
        } catch {
            await peer.stop()
            throw error
        }
        await peer.stop()
    }
}
