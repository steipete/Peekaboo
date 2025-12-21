import CoreGraphics
import Foundation
import os.log

public enum WindowMovementAdjustment: Sendable {
    case unchanged(CGPoint)
    case adjusted(CGPoint, delta: CGPoint)
    case stale(String)
}

public protocol WindowTrackingProviding: AnyObject, Sendable {
    @MainActor func windowBounds(for windowID: CGWindowID) -> CGRect?
}

@MainActor
public enum WindowMovementTracking {
    private static let logger = Logger(subsystem: "boo.peekaboo.core", category: "WindowMovementTracking")
    private static let identityService = WindowIdentityService()

    public weak static var provider: (any WindowTrackingProviding)?

    public static func adjustPoint(
        _ point: CGPoint,
        snapshot: UIAutomationSnapshot) -> WindowMovementAdjustment
    {
        guard let windowID = snapshot.windowID,
              let snapshotBounds = snapshot.windowBounds
        else {
            return .unchanged(point)
        }

        let currentBounds = self.currentBounds(for: windowID)
        guard let currentBounds else {
            return .unchanged(point)
        }

        if currentBounds.size != snapshotBounds.size {
            let message = "Window resized from \(snapshotBounds.size) to \(currentBounds.size)"
            return .stale(message)
        }

        let delta = CGPoint(
            x: currentBounds.origin.x - snapshotBounds.origin.x,
            y: currentBounds.origin.y - snapshotBounds.origin.y)

        guard delta != .zero else {
            return .unchanged(point)
        }

        let adjusted = CGPoint(x: point.x + delta.x, y: point.y + delta.y)
        self.logger.debug("Adjusted point for moved window dx=\(delta.x) dy=\(delta.y)")
        return .adjusted(adjusted, delta: delta)
    }

    public static func adjustFrame(
        _ frame: CGRect,
        snapshot: UIAutomationSnapshot) -> WindowMovementAdjustment
    {
        let point = CGPoint(x: frame.midX, y: frame.midY)
        return self.adjustPoint(point, snapshot: snapshot)
    }

    private static func currentBounds(for windowID: CGWindowID) -> CGRect? {
        if let provider = self.provider {
            return provider.windowBounds(for: windowID)
        }
        return self.identityService.getWindowInfo(windowID: windowID)?.bounds
    }
}
