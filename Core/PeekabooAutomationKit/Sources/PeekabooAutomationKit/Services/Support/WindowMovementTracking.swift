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

        guard let currentBounds = self.currentBounds(for: windowID) else {
            let identity = self.windowIdentityDescription(snapshot: snapshot, windowID: windowID)
            return .stale(
                """
                Snapshot window is no longer available (\(identity)). \
                Run 'peekaboo see' again before targeting elements from this snapshot.
                """)
        }

        if currentBounds.size != snapshotBounds.size {
            let identity = self.windowIdentityDescription(snapshot: snapshot, windowID: windowID)
            let message = """
            Snapshot window changed size (\(identity)). \
            Previous bounds: \(snapshotBounds); current bounds: \(currentBounds). \
            Run 'peekaboo see' again before targeting elements from this snapshot.
            """
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

    private static func windowIdentityDescription(
        snapshot: UIAutomationSnapshot,
        windowID: CGWindowID) -> String
    {
        var parts = ["windowID: \(windowID)"]
        if let applicationName = snapshot.applicationName {
            parts.append("app: \(applicationName)")
        }
        if let applicationBundleId = snapshot.applicationBundleId {
            parts.append("bundle: \(applicationBundleId)")
        }
        if let windowTitle = snapshot.windowTitle {
            parts.append("title: \(windowTitle)")
        }
        return parts.joined(separator: ", ")
    }
}
