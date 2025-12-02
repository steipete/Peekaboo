import Foundation

public enum PeekabooXPCConstants {
    /// Default mach service name for the helper LaunchAgent.
    public static let serviceName = "boo.peekaboo.helper"

    /// Current protocol version supported by this build.
    public static let protocolVersion = PeekabooXPCProtocolVersion(major: 1, minor: 0)

    /// Compatible protocol range for negotiation. Update when introducing breaking changes.
    public static let supportedProtocolRange: ClosedRange<PeekabooXPCProtocolVersion> =
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
}

extension JSONEncoder {
    public static func peekabooXPCEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    public static func peekabooXPCDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
