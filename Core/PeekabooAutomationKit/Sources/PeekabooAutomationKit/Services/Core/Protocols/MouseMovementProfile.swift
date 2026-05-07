import CoreGraphics
import Foundation
import PeekabooFoundation

/// Profiles controlling how mouse paths are generated.
public enum MouseMovementProfile: Sendable, Equatable, Codable {
    /// Linear interpolation between the current and target coordinate.
    case linear
    /// Human-style motion with eased velocity, micro-jitter, and subtle overshoot.
    case human(HumanMouseProfileConfiguration = .default)

    private enum CodingKeys: String, CodingKey { case kind, profile }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "linear":
            self = .linear
        case "human":
            let profile = try container.decodeIfPresent(HumanMouseProfileConfiguration.self, forKey: .profile) ??
                .default
            self = .human(profile)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "Unknown MouseMovementProfile kind: \(kind)")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .linear:
            try container.encode("linear", forKey: .kind)
        case let .human(profile):
            try container.encode("human", forKey: .kind)
            try container.encode(profile, forKey: .profile)
        }
    }
}

/// Tunable values for the human-style mouse movement profile.
public struct HumanMouseProfileConfiguration: Sendable, Equatable, Codable {
    public var jitterAmplitude: CGFloat
    public var overshootProbability: Double
    public var overshootFractionRange: ClosedRange<Double>
    public var settleRadius: CGFloat
    public var randomSeed: UInt64?

    public init(
        jitterAmplitude: CGFloat = 0.35,
        overshootProbability: Double = 0.2,
        overshootFractionRange: ClosedRange<Double> = 0.02...0.06,
        settleRadius: CGFloat = 6,
        randomSeed: UInt64? = nil)
    {
        self.jitterAmplitude = jitterAmplitude
        self.overshootProbability = overshootProbability
        self.overshootFractionRange = overshootFractionRange
        self.settleRadius = settleRadius
        self.randomSeed = randomSeed
    }

    public static let `default` = HumanMouseProfileConfiguration()
}
