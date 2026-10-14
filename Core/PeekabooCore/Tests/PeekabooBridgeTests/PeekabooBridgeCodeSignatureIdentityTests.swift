import Darwin
import Foundation
import Security
import Testing
@testable import PeekabooBridge

struct PeekabooBridgeCodeSignatureIdentityTests {
    typealias Failure = PeekabooBridgeCodeSignatureIdentity.SigningValidationFailure
    private static let hash = Data(repeating: 0xA5, count: 20)

    @Test(arguments: [
        "live", "lookup", "hash", "identifier", "team", "changed", "anchor", "missingHash", "missingTeam",
    ])
    func `signing failures identify the failed binding check`(check: String) throws {
        let peer = try Self.peerIdentity()
        var lookups = 0
        let failure = try #require(throws: Failure.self) {
            _ = try PeekabooBridgeCodeSignatureIdentity.validatedSigningInformation(
                auditIdentity: peer,
                systemCall: { _, _, address, count, _ in
                    lookups += 1
                    guard check != "live", let address else { return -1 }
                    let hash = check == "changed" && lookups > 1 ? Data(repeating: 0xB6, count: 20) : Self.hash
                    hash.withUnsafeBytes { address.copyMemory(from: $0.baseAddress!, byteCount: count) }
                    return 0
                },
                staticSigningInformationProvider: { _ in
                    if check == "lookup" {
                        return nil
                    }
                    var information: [String: Any] = [
                        kSecCodeInfoIdentifier as String: "boo.peekaboo.peekaboo",
                        kSecCodeInfoTeamIdentifier as String: "TRUSTED",
                        kSecCodeInfoUnique as String: check == "hash" ? Data(repeating: 0xB6, count: 20) : Self.hash,
                    ]
                    if check == "missingHash" {
                        information.removeValue(forKey: kSecCodeInfoUnique as String)
                    }
                    if check == "missingTeam" {
                        information.removeValue(forKey: kSecCodeInfoTeamIdentifier as String)
                    }
                    return information
                },
                anchoredSignatureValidationProvider: { _ in
                    if check == "anchor" {
                        return nil
                    }
                    return .init(
                        identifier: check == "identifier" ? "other" : "boo.peekaboo.peekaboo",
                        teamIdentifier: check == "team" ? "OTHER" : "TRUSTED",
                        codeDirectoryHash: Self.hash)
                })
        }
        let expected: [String: Failure] = [
            "live": .liveCDHashUnavailable, "lookup": .signingInformationUnavailable,
            "hash": .staticCDHashMismatch, "identifier": .staticIdentifierMismatch,
            "team": .staticTeamMismatch, "changed": .liveCDHashChanged, "anchor": .anchoredValidationUnavailable,
            "missingHash": .staticCDHashUnavailable, "missingTeam": .staticIdentifierOrTeamUnavailable,
        ]
        #expect(failure == expected[check])
        try Self.assertTrustDiagnostic(failure)
    }

    @Test(arguments: [
        Failure.guestCodeLookupFailed(-67062), .staticCodeLookupFailed(-67050),
        .liveAnchoredRequirementNotSatisfied(-67050), .staticAnchoredRequirementNotSatisfied(-67061),
    ])
    func `security framework failures retain their operation and OSStatus`(failure: Failure) throws {
        let observed = try #require(throws: Failure.self) {
            _ = try PeekabooBridgeCodeSignatureIdentity.validatedSigningInformation(
                auditIdentity: Self.peerIdentity(),
                systemCall: { _, _, address, count, _ in
                    Self.hash.withUnsafeBytes { address?.copyMemory(from: $0.baseAddress!, byteCount: count) }
                    return 0
                },
                staticSigningInformationProvider: { _ in
                    if case .guestCodeLookupFailed = failure {
                        throw failure
                    }
                    if case .staticCodeLookupFailed = failure {
                        throw failure
                    }
                    return [
                        kSecCodeInfoIdentifier as String: "boo.peekaboo.peekaboo",
                        kSecCodeInfoTeamIdentifier as String: "TRUSTED",
                        kSecCodeInfoUnique as String: Self.hash,
                    ]
                },
                anchoredSignatureValidationProvider: { _ in throw failure })
        }
        #expect(observed == failure)
        #expect(observed.localizedDescription.contains("OSStatus -670"))
        try Self.assertTrustDiagnostic(observed)
    }

    private static func assertTrustDiagnostic(_ failure: Failure) throws {
        let host = PeekabooBridgeConnectedHostIdentity(
            liveIdentity: .init(
                auditToken: Data(),
                processIdentifier: 739,
                processIdentifierVersion: 1,
                effectiveUserIdentifier: 501,
                processStartIdentity: 1,
                codeSignatureHash: "live-hash"),
            signingIdentity: nil,
            signingIdentityFailure: failure)
        let error = try #require(throws: PeekabooBridgeErrorEnvelope.self) {
            try PeekabooBridgeConnectedHostTrust.validate(
                host, socketPath: "/fixture/daemon.sock", trustedTeamIDs: ["TRUSTED"])
        }
        #expect(error.code == .unauthorizedClient)
        #expect(error.isLocalHostAuthenticationFailure)
        #expect(error.message.contains("Apple-anchored signing identity could not be bound to the live peer"))
        #expect(error.message.contains(failure.localizedDescription))
    }

    private static func peerIdentity() throws -> PeekabooBridgePeerAuditIdentity {
        var descriptors: [Int32] = [-1, -1]
        guard socketpair(AF_UNIX, SOCK_STREAM, 0, &descriptors) == 0 else { throw POSIXError(.EIO) }
        defer {
            close(descriptors[0])
            close(descriptors[1])
        }
        return try PeekabooBridgeSocketIO.peerAuditIdentity(fd: descriptors[0])
    }
}
