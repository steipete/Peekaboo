import CoreGraphics
import PeekabooAutomation

enum MovementProfileOption: String {
    case linear
    case human
}

struct MovementParameters {
    let profile: MouseMovementProfile
    let duration: Int
    let steps: Int
    let smooth: Bool
    let profileName: String
}

enum HumanizedMovementDefaults {
    static let defaultSteps = 60
    static let defaultDuration = 650

    static func duration(for distance: CGFloat) -> Int {
        let distanceFactor = log2(Double(distance) + 1) * 90
        let perPixel = Double(distance) * 0.45
        let estimate = 280 + distanceFactor + perPixel
        return min(max(Int(estimate), 300), 1700)
    }

    static func steps(for distance: CGFloat) -> Int {
        let scaled = Int(distance * 0.35)
        return min(max(scaled, 30), 140)
    }
}

extension MovementProfileOption {
    func resolveParameters(
        smooth: Bool,
        durationOverride: Int?,
        stepsOverride: Int?,
        defaultDuration: Int,
        defaultSteps: Int,
        distance: CGFloat
    ) -> MovementParameters {
        switch self {
        case .linear:
            let duration = durationOverride ?? (smooth ? defaultDuration : 0)
            let steps = smooth ? max(stepsOverride ?? defaultSteps, 1) : 1
            return MovementParameters(
                profile: .linear,
                duration: duration,
                steps: steps,
                smooth: smooth,
                profileName: self.rawValue
            )
        case .human:
            let duration = durationOverride ?? HumanizedMovementDefaults.duration(for: distance)
            let steps = max(
                stepsOverride ?? HumanizedMovementDefaults.defaultSteps,
                HumanizedMovementDefaults.steps(for: distance)
            )
            return MovementParameters(
                profile: .human(),
                duration: duration,
                steps: steps,
                smooth: true,
                profileName: self.rawValue
            )
        }
    }
}
