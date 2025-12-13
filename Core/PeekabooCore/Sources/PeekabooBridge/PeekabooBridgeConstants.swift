import Foundation

public enum PeekabooBridgeConstants {
    public static let socketName = "bridge.sock"

    /// Socket hosted by Peekaboo.app (primary host).
    public static var peekabooSocketPath: String {
        self.applicationSupportSocketPath(appDirectoryName: "Peekaboo")
    }

    /// Socket hosted by Clawdis.app (fallback host).
    public static var clawdisSocketPath: String {
        self.applicationSupportSocketPath(appDirectoryName: "clawdis")
    }

    /// Current protocol version supported by this build.
    public static let protocolVersion = PeekabooBridgeProtocolVersion(major: 1, minor: 0)

    /// Compatible protocol range for negotiation. Update when introducing breaking changes.
    public static let supportedProtocolRange: ClosedRange<PeekabooBridgeProtocolVersion> =
        protocolVersion...protocolVersion

    /// Build identifier advertised during handshake (falls back to "dev").
    public static var buildIdentifier: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleVersion"] as? String
        let short = info?["CFBundleShortVersionString"] as? String
        switch (short, version) {
        case let (short?, version?):
            return "\(short) (\(version))"
        case let (nil, version?):
            return version
        default:
            return "dev"
        }
    }

    private static func applicationSupportSocketPath(appDirectoryName: String) -> String {
        let fileManager = FileManager.default
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let directory = baseDirectory.appendingPathComponent(appDirectoryName, isDirectory: true)
        return directory.appendingPathComponent(self.socketName, isDirectory: false).path
    }
}

extension JSONEncoder {
    public static func peekabooBridgeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    public static func peekabooBridgeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
