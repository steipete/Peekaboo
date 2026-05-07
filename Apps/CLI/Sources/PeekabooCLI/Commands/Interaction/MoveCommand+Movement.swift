import CoreGraphics
import Foundation
import PeekabooCore

extension MoveCommand {
    var selectedProfile: MovementProfileSelection {
        guard let profileName = self.profile?.lowercased(),
              let selection = MovementProfileSelection(rawValue: profileName) else {
            return .linear
        }
        return selection
    }

    func resolveMovementParameters(
        profileSelection: MovementProfileSelection,
        distance: CGFloat
    ) -> MovementParameters {
        switch profileSelection {
        case .linear:
            let wantsSmooth = self.smooth || (self.duration ?? 0) > 0
            let resolvedDuration: Int = if let customDuration = self.duration {
                customDuration
            } else {
                wantsSmooth ? 500 : 0
            }
            let resolvedSteps = wantsSmooth ? max(self.steps, 1) : 1
            return MovementParameters(
                profile: .linear,
                duration: resolvedDuration,
                steps: resolvedSteps,
                smooth: wantsSmooth,
                profileName: profileSelection.rawValue
            )
        case .human:
            let resolvedDuration = self.duration ?? self.defaultHumanDuration(for: distance)
            let resolvedSteps = max(self.steps, self.defaultHumanSteps(for: distance))
            return MovementParameters(
                profile: .human(),
                duration: resolvedDuration,
                steps: resolvedSteps,
                smooth: true,
                profileName: profileSelection.rawValue
            )
        }
    }

    private func defaultHumanDuration(for distance: CGFloat) -> Int {
        let distanceFactor = log2(Double(distance) + 1) * 90
        let perPixel = Double(distance) * 0.45
        let estimate = 240 + distanceFactor + perPixel
        return min(max(Int(estimate), 280), 1700)
    }

    private func defaultHumanSteps(for distance: CGFloat) -> Int {
        let scaled = Int(distance * 0.35)
        return min(max(scaled, 30), 120)
    }
}
