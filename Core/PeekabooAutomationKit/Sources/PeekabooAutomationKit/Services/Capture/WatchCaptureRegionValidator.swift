import CoreGraphics
import Foundation
import PeekabooFoundation

struct WatchCaptureRegionValidator {
    let screenService: (any ScreenServiceProtocol)?

    @MainActor
    func validateRegion(_ rect: CGRect) throws -> (rect: CGRect, warning: WatchWarning?) {
        let screens = self.screenService?.listScreens() ?? []
        guard !screens.isEmpty else {
            throw PeekabooError.invalidInput("No screens available for region capture")
        }

        // Watch capture expects global coordinates; clamp partially visible regions to all-screen bounds.
        let union = screens.reduce(CGRect.null) { partial, screen in
            partial.union(screen.frame)
        }
        guard rect.intersects(union) else {
            throw PeekabooError.invalidInput("Region lies outside all screens")
        }

        let clamped = rect.intersection(union)
        guard clamped != rect else {
            return (clamped, nil)
        }

        return (
            clamped,
            WatchWarning(code: .displayChanged, message: "Region adjusted to visible area"))
    }
}
