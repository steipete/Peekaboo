import Foundation
import PeekabooBridgeTestSupport
import Testing
@testable import PeekabooBridge

struct PeekabooBridgeSigningDiagnosticsTests {
    @Test(arguments: [
        ("FWJYW4S8P8", false, true, true),
        ("Y5PE65HELJ", false, true, true),
        (nil, false, true, false),
        ("", false, true, false),
        ("OTHER", false, true, false),
        ("FWJYW4S8P8", true, true, false),
        ("FWJYW4S8P8", false, false, false),
        (nil, true, false, false),
    ] as [(String?, Bool, Bool, Bool)])
    func `release classification requires an anchored non adhoc trusted team`(
        team: String?, isAdHoc: Bool, isAppleAnchored: Bool, expected: Bool)
    {
        #expect(PeekabooBridgeSigningDiagnostics.isReleaseSigned(
            teamIdentifier: team, isAdHoc: isAdHoc, isAppleAnchored: isAppleAnchored) == expected)
    }

    @Test(arguments: [false, true])
    func `host authentication guidance depends on the current process signature`(releaseSigned: Bool) throws {
        let error = try #require(throws: PeekabooBridgeErrorEnvelope.self) {
            try PeekabooBridgeConnectedHostTrust.validate(
                nil,
                socketPath: "/fixture/bridge.sock",
                trustedTeamIDs: ["FWJYW4S8P8"],
                currentProcessIsReleaseSigned: { releaseSigned })
        }
        let original = "Bridge host authentication failed at '/fixture/bridge.sock': " +
            "connected socket peer identity is unavailable. " +
            "Relaunch the released signed host at this socket; if its executable was replaced, " +
            "stop the old host process and restart it from the current signed app or CLI. " +
            "Chrome approval and browser receipts have not been checked."
        #expect(error.message == original + (releaseSigned ? "" : " " + Self.hint))
        #expect(error.code == .unauthorizedClient)
        #expect(error.context == "connectedHostAuthentication")
        #expect(error.isLocalHostAuthenticationFailure)
    }

    @Test(arguments: [false, true])
    func `structured client rejection gains only local installation guidance`(releaseSigned: Bool) async throws {
        let peer = try ScriptedBridgePeer(responses: [
            .error(.init(code: .unauthorizedClient, message: "Bridge client is not authorized", details: "fixture")),
        ])
        let client = PeekabooBridgeClient(
            socketPath: peer.socketPath,
            trustedHostTeamIDs: ["FWJYW4S8P8"],
            hostAuthentication: .init(
                signingIdentity: { identity in
                    guard let hash = PeekabooBridgeCodeSignatureIdentity.codeSignatureHash(auditIdentity: identity)
                    else { return nil }
                    return .init(
                        bundleIdentifier: "boo.peekaboo.mac", teamIdentifier: "FWJYW4S8P8", codeSignatureHash: hash)
                },
                currentProcessIsReleaseSigned: { releaseSigned }))
        let error = await #expect(throws: PeekabooBridgeErrorEnvelope.self) {
            try await client.handshake(client: .init(
                bundleIdentifier: nil, teamIdentifier: nil, processIdentifier: 42))
        }
        await peer.stop()
        let rejection = try #require(error)
        #expect(rejection.message == "Bridge client is not authorized" + (releaseSigned ? "" : " " + Self.hint))
        #expect(rejection.code == .unauthorizedClient)
        #expect(rejection.details == "fixture")
        #expect(!rejection.isLocalHostAuthenticationFailure)
    }

    @Test
    func `installation guidance is appended at most once`() {
        let message = "Original failure. " + Self.hint
        #expect(PeekabooBridgeSigningDiagnostics.appendingUnsignedBuildHint(
            to: message, currentProcessIsReleaseSigned: false) == message)
    }

    private static let hint =
        "This peekaboo binary is not release-signed (for example Homebrew core's source-built `peekaboo` formula " +
        "or a local `swift build`), so Peekaboo Bridge and daemon hosts cannot trust it; install the notarized CLI " +
        "with `brew install openclaw/tap/peekaboo` or `npm i -g @steipete/peekaboo`."
}
