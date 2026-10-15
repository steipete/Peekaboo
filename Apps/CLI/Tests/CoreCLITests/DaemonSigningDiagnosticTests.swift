import Foundation
import PeekabooBridgeTestSupport
import Testing
@testable import PeekabooBridge
@testable import PeekabooCLI

@MainActor
@Suite(.serialized, .tags(.safe))
struct DaemonSigningDiagnosticTests {
    @Test(arguments: [false, true])
    func `readiness timeout preserves its message for release signed callers`(releaseSigned: Bool) {
        let error = DaemonLaunchPolicy.DaemonLaunchError.timedOut(
            timeout: 10,
            elapsed: 10.25,
            lastProbeError: "Fixture probe failure",
            logURL: URL(fileURLWithPath: "/fixture/daemon.log")
        )
        let original = "Peekaboo daemon did not become ready within 10s " +
            "(elapsed 10.25s); last probe: Fixture probe failure; see /fixture/daemon.log"
        #expect(error.description(currentProcessIsReleaseSigned: { releaseSigned }) ==
            original + (releaseSigned ? "" : " " + Self.hint))
    }

    @Test
    func `readiness timeout does not repeat guidance retained in the probe failure`() {
        let error = DaemonLaunchPolicy.DaemonLaunchError.timedOut(
            timeout: 10,
            elapsed: 10.25,
            lastProbeError: "Fixture failure. " + Self.hint,
            logURL: URL(fileURLWithPath: "/fixture/daemon.log")
        )
        let message = error.description(currentProcessIsReleaseSigned: { false })
        #expect(message.components(separatedBy: Self.hint).count == 2)
    }

    @Test(arguments: [false, true], [false, true])
    func `daemon status preserves authentication failure with caller signing guidance`(
        releaseSigned: Bool, hostAuthenticationFails: Bool
    ) async throws {
        let peer = try ScriptedBridgePeer(responses: [.error(.init(
            code: .unauthorizedClient, message: "Client signing team is not trusted"
        ))])
        let client = Self.client(
            socketPath: peer.socketPath,
            releaseSigned: releaseSigned,
            hostAuthenticationFails: hostAuthenticationFails
        )
        let error = await #expect(throws: PeekabooBridgeErrorEnvelope.self) {
            try await DaemonControlClient(socketPath: peer.socketPath).fetchStatus(using: client)
        }
        await peer.stop()
        let failure = try #require(error)
        let original = hostAuthenticationFails ? Self.hostFailure(socketPath: peer.socketPath) :
            "Client signing team is not trusted"
        #expect(failure.message == original + (releaseSigned ? "" : " " + Self.hint))
        #expect(failure.code == .unauthorizedClient)
        #expect(failure.isLocalHostAuthenticationFailure == hostAuthenticationFails)
        #expect(!failure.operationMayHaveCompleted)
    }

    @Test(arguments: [false, true])
    func `daemon status rejection after handshake retains the same guidance`(releaseSigned: Bool) async throws {
        let peer = try ScriptedBridgePeer(responses: [
            .handshake(BridgeTestFixtures.handshake(
                negotiatedVersion: .init(major: 1, minor: 28),
                hostKind: .onDemand,
                supportedOperations: [.daemonStatus]
            )),
            .error(.init(code: .unauthorizedClient, message: "Bridge client is not authorized")),
        ])
        let client = Self.client(
            socketPath: peer.socketPath,
            releaseSigned: releaseSigned,
            hostAuthenticationFails: false
        )
        let error = await #expect(throws: PeekabooBridgeErrorEnvelope.self) {
            try await DaemonControlClient(socketPath: peer.socketPath).fetchStatus(using: client)
        }
        await peer.stop()
        #expect(error?.message == "Bridge client is not authorized" + (releaseSigned ? "" : " " + Self.hint))
        #expect(error?.isLocalHostAuthenticationFailure == false)
    }

    @Test(arguments: [false, true])
    func `daemon readiness rethrows authentication failure instead of waiting for timeout`(
        releaseSigned: Bool
    ) async throws {
        let peer = try ScriptedBridgePeer(responses: [.error(.init(code: .unauthorizedClient, message: "Unused"))])
        let client = Self.client(
            socketPath: peer.socketPath,
            releaseSigned: releaseSigned,
            hostAuthenticationFails: true
        )
        let error = await #expect(throws: PeekabooBridgeErrorEnvelope.self) {
            try await DaemonLaunchPolicy.launchDaemon(
                socketPath: peer.socketPath,
                arguments: ["30"],
                timeout: 2,
                executableURL: URL(fileURLWithPath: "/bin/sleep"),
                logHandle: .nullDevice,
                probe: { control in try await control.fetchStatus(using: client) }
            )
        }
        await peer.stop()
        let failure = try #require(error)
        #expect(failure.message == Self
            .hostFailure(socketPath: peer.socketPath) + (releaseSigned ? "" : " " + Self.hint))
        #expect(failure.isLocalHostAuthenticationFailure)
        #expect(!DaemonLaunchPolicy.isRetryableReadinessError(failure))
    }

    private static func client(
        socketPath: String, releaseSigned: Bool, hostAuthenticationFails: Bool
    ) -> PeekabooBridgeClient {
        if !hostAuthenticationFails {
            return PeekabooBridgeClient(
                socketPath: socketPath,
                trustedHostTeamIDs: ["FWJYW4S8P8"],
                hostAuthentication: .init(
                    signingIdentity: { identity in
                        guard let hash = PeekabooBridgeCodeSignatureIdentity.codeSignatureHash(auditIdentity: identity)
                        else { return nil }
                        return .init(
                            bundleIdentifier: "boo.peekaboo.peekaboo",
                            teamIdentifier: "FWJYW4S8P8",
                            codeSignatureHash: hash
                        )
                    },
                    currentProcessIsReleaseSigned: { releaseSigned }
                )
            )
        }
        return PeekabooBridgeClient(
            socketPath: socketPath,
            trustedHostTeamIDs: ["FWJYW4S8P8"],
            hostAuthentication: .init(
                liveIdentity: { _ in
                    .init(
                        auditToken: Data(),
                        processIdentifier: 739,
                        processIdentifierVersion: 1,
                        effectiveUserIdentifier: 501,
                        processStartIdentity: 1,
                        codeSignatureHash: "live-hash"
                    )
                },
                signingIdentity: { _ in nil },
                currentProcessIsReleaseSigned: { releaseSigned }
            )
        )
    }

    private static func hostFailure(socketPath: String) -> String {
        "Bridge host authentication failed at '\(socketPath)' (PID 739): " +
            "Apple-anchored signing identity could not be bound to the live peer. " +
            "Relaunch the released signed host at this socket; if its executable was replaced, " +
            "stop the old host process and restart it from the current signed app or CLI. " +
            "Chrome approval and browser receipts have not been checked."
    }

    private static let hint =
        "This peekaboo binary is not release-signed (for example Homebrew core's source-built `peekaboo` formula " +
        "or a local `swift build`), so Peekaboo Bridge and daemon hosts cannot trust it; install the notarized CLI " +
        "with `brew install openclaw/tap/peekaboo` or `npm i -g @steipete/peekaboo`."
}
