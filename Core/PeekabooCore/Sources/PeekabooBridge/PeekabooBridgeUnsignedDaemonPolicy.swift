import Darwin
import Foundation

public enum PeekabooBridgeTrustMode: String, Codable, Sendable {
    case releaseSignature
    case unsignedSameBinaryDeveloperOptIn

    public var description: String {
        switch self {
        case .releaseSignature: "release signature"
        case .unsignedSameBinaryDeveloperOptIn: "unsigned same-binary developer opt-in"
        }
    }
}

/// A local policy only: neither wire metadata nor executable paths can authorize this exception.
struct PeekabooBridgeUnsignedDaemonPolicy: Sendable {
    let enabled: Bool
    let effectiveUserIdentifier: uid_t
    let codeSignatureHash: String?

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        currentProcessIsReleaseSigned: () -> Bool = PeekabooBridgeSigningDiagnostics.currentProcessIsReleaseSigned,
        effectiveUserIdentifier: uid_t = geteuid(),
        codeSignatureHash: () -> String? = {
            PeekabooBridgeCodeSignatureIdentity.codeSignatureHash(processIdentifier: getpid())
        })
    {
        self.enabled = environment["PEEKABOO_ALLOW_UNSIGNED_DAEMON"] == "1" && !currentProcessIsReleaseSigned()
        self.effectiveUserIdentifier = effectiveUserIdentifier
        self.codeSignatureHash = self.enabled ? codeSignatureHash() : nil
    }

    func allows(_ peer: PeekabooBridgeLivePeerIdentity, hostKind: PeekabooBridgeHostKind?) -> Bool {
        self.enabled && hostKind == .onDemand &&
            peer.effectiveUserIdentifier == self.effectiveUserIdentifier &&
            self.codeSignatureHash?.isEmpty == false && peer.codeSignatureHash == self.codeSignatureHash
    }
}
