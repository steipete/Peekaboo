import Darwin
import Foundation
import Testing
@testable import PeekabooBridge

struct PeekabooBridgeUnsignedDaemonTests {
    private static let cases = [
        "same", "release", "missing", "zero", "otherValue", "hash", "uid", "gui", "helper", "missingHash", "emptyHash",
    ]

    private func policy(_ scenario: String) -> PeekabooBridgeUnsignedDaemonPolicy {
        let environment: [String: String] = switch scenario {
        case "missing": [:]
        case "zero": ["PEEKABOO_ALLOW_UNSIGNED_DAEMON": "0"]
        case "otherValue": ["PEEKABOO_ALLOW_UNSIGNED_DAEMON": "true"]
        default: ["PEEKABOO_ALLOW_UNSIGNED_DAEMON": "1"]
        }
        return .init(
            environment: environment,
            currentProcessIsReleaseSigned: { scenario == "release" },
            effectiveUserIdentifier: scenario == "uid" ? geteuid() &+ 1 : geteuid(),
            codeSignatureHash: {
                switch scenario {
                case "hash": "other-hash"
                case "missingHash": nil
                case "emptyHash": ""
                default: "own-live-hash"
                }
            })
    }

    private func hostKind(_ scenario: String) -> PeekabooBridgeHostKind {
        switch scenario {
        case "gui": .gui
        case "helper": .helper
        default: .onDemand
        }
    }

    @Test(arguments: Self.cases)
    func `client trusts only opted in unsigned same binary daemon`(scenario: String) throws {
        let live = PeekabooBridgeLivePeerIdentity(
            auditToken: Data(),
            processIdentifier: 739,
            processIdentifierVersion: 1,
            effectiveUserIdentifier: geteuid(),
            processStartIdentity: 1,
            codeSignatureHash: "own-live-hash")
        let host = PeekabooBridgeConnectedHostIdentity(
            liveIdentity: live,
            signingIdentity: nil)
        if scenario == "same" {
            let mode = try PeekabooBridgeConnectedHostTrust.validate(
                host,
                socketPath: "/fixture/daemon.sock",
                trustedTeamIDs: ["RELEASE"],
                hostKind: self.hostKind(scenario),
                unsignedDaemonPolicy: self.policy(scenario),
                currentProcessIsReleaseSigned: { false })
            #expect(mode == .unsignedSameBinaryDeveloperOptIn)
        } else {
            #expect(throws: PeekabooBridgeErrorEnvelope.self) {
                try PeekabooBridgeConnectedHostTrust.validate(
                    host,
                    socketPath: "/fixture/daemon.sock",
                    trustedTeamIDs: ["RELEASE"],
                    hostKind: self.hostKind(scenario),
                    unsignedDaemonPolicy: self.policy(scenario),
                    currentProcessIsReleaseSigned: { scenario == "release" })
            }
        }
    }

    @Test(arguments: Self.cases, [false, true])
    func `host admits only opted in unsigned same binary daemon clients`(
        scenario: String,
        emptyAllowlist: Bool) throws
    {
        let live = try self.liveIdentity()
        let peer = PeekabooBridgeHost.peerInfoIfAllowed(
            liveIdentity: live,
            allowedTeamIDs: emptyAllowlist ? [] : ["RELEASE"],
            signingIdentityProvider: { _ in nil },
            allowUnsignedSocketClients: false,
            hostKind: self.hostKind(scenario),
            unsignedDaemonPolicy: self.policy(scenario))
        let legacyAdmission = emptyAllowlist && ["release", "missing", "zero", "otherValue", "gui", "helper"]
            .contains(scenario)
        #expect((peer != nil) == (scenario == "same" || legacyAdmission))
        if let peer {
            #expect(peer.trustMode == (scenario == "same" ? .unsignedSameBinaryDeveloperOptIn : nil))
            #expect(peer.teamIdentifier == nil)
            #expect(peer.codeSignatureHash == "own-live-hash")
        }
    }

    @Test
    func `release classification prevents reading the developer hash`() {
        let policy = PeekabooBridgeUnsignedDaemonPolicy(
            environment: ["PEEKABOO_ALLOW_UNSIGNED_DAEMON": "1"],
            currentProcessIsReleaseSigned: { true },
            codeSignatureHash: {
                Issue.record("Release processes must ignore the opt-in")
                return "own-live-hash"
            })
        #expect(!policy.enabled)
    }

    @Test(arguments: [false, true])
    func `opted in daemon rejects release team clients running another binary`(optedIn: Bool) throws {
        let live = try self.liveIdentity(codeSignatureHash: "release-client-hash")
        let peer = PeekabooBridgeHost.peerInfoIfAllowed(
            liveIdentity: live,
            allowedTeamIDs: ["RELEASE"],
            signingIdentityProvider: { _ in
                PeekabooBridgeHost.PeerSigningIdentity(
                    bundleIdentifier: "boo.peekaboo.peekaboo",
                    teamIdentifier: "RELEASE",
                    codeSignatureHash: "release-client-hash")
            },
            allowUnsignedSocketClients: false,
            hostKind: .onDemand,
            unsignedDaemonPolicy: self.policy(optedIn ? "same" : "missing"))
        // Without the opt-in the team allowlist admits the release client as before.
        #expect((peer != nil) == !optedIn)
    }

    @Test
    func `host still rejects a changed process generation`() throws {
        let live = try self.liveIdentity(stale: true)
        #expect(PeekabooBridgeHost.peerInfoIfAllowed(
            liveIdentity: live,
            allowedTeamIDs: ["RELEASE"],
            signingIdentityProvider: { _ in nil },
            allowUnsignedSocketClients: false,
            hostKind: .onDemand,
            unsignedDaemonPolicy: self.policy("same")) == nil)
    }

    @Test
    func `wire trust mode cannot grant developer trust`() throws {
        var handshake = PeekabooBridgeHandshakeResponse(
            negotiatedVersion: .init(
                major: 1,
                minor: 28),
            hostKind: .onDemand,
            build: nil,
            supportedOperations: [])
        handshake.trustMode = .unsignedSameBinaryDeveloperOptIn
        let encoded = try JSONEncoder().encode(handshake)
        #expect(String(data: encoded, encoding: .utf8)?.contains("unsignedSameBinaryDeveloperOptIn") == true)
        #expect(try JSONDecoder().decode(
            PeekabooBridgeHandshakeResponse.self,
            from: encoded).trustMode == nil)
    }

    private func liveIdentity(
        stale: Bool = false,
        codeSignatureHash: String = "own-live-hash") throws -> PeekabooBridgeLivePeerIdentity
    {
        var sockets: [Int32] = [0, 0]
        guard socketpair(AF_UNIX, SOCK_STREAM, 0, &sockets) == 0 else { throw POSIXError(.EIO) }
        defer {
            close(sockets[0])
            close(sockets[1])
        }
        let live = try PeekabooBridgeSocketIO.livePeerIdentity(fd: sockets[0])
        return .init(
            auditToken: live.auditToken,
            processIdentifier: live.processIdentifier,
            processIdentifierVersion: live.processIdentifierVersion,
            effectiveUserIdentifier: live.effectiveUserIdentifier,
            processStartIdentity: live.processStartIdentity + (stale ? 1 : 0),
            codeSignatureHash: codeSignatureHash)
    }
}
