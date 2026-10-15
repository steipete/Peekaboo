import Security

/// Installation guidance only; this classification never grants Bridge admission.
public enum PeekabooBridgeSigningDiagnostics {
    public static func isReleaseSigned(
        teamIdentifier: String?,
        isAdHoc: Bool,
        isAppleAnchored: Bool) -> Bool
    {
        guard isAppleAnchored, !isAdHoc, let teamIdentifier else { return false }
        return PeekabooBridgeConstants.trustedReleaseTeamIDs.contains(teamIdentifier)
    }

    public static func currentProcessIsReleaseSigned() -> Bool {
        let information = PeekabooBridgeCodeSignatureIdentity.authenticatedCurrentProcessSigningInformation()
        let flags = information?[kSecCodeInfoFlags as String] as? UInt32 ?? 0
        return self.isReleaseSigned(
            teamIdentifier: information?[kSecCodeInfoTeamIdentifier as String] as? String,
            isAdHoc: flags & SecCodeSignatureFlags.adhoc.rawValue != 0,
            isAppleAnchored: information != nil)
    }

    public static let unsignedBuildHint =
        "This peekaboo binary is not release-signed (for example Homebrew core's source-built `peekaboo` formula " +
        "or a local `swift build`), so Peekaboo Bridge and daemon hosts cannot trust it; install the notarized CLI " +
        "with `brew install openclaw/tap/peekaboo` or `npm i -g @steipete/peekaboo`."

    public static func appendingUnsignedBuildHint(
        to message: String,
        currentProcessIsReleaseSigned: Bool = PeekabooBridgeSigningDiagnostics
            .currentProcessIsReleaseSigned()) -> String
    {
        guard !currentProcessIsReleaseSigned, !message.contains(self.unsignedBuildHint) else { return message }
        return message + " " + self.unsignedBuildHint
    }
}
