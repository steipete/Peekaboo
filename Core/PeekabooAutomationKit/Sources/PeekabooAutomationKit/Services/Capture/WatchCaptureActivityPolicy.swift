import Foundation

enum WatchCaptureActivityPolicy {
    /// Returns true when the capture loop should drop from active to idle cadence.
    /// We leave active mode once change is below half the threshold for at least `quietMs`.
    static func shouldExitActive(
        changePercent: Double,
        threshold: Double,
        lastActivityTime: Date,
        quietMs: Int,
        now: Date) -> Bool
    {
        guard changePercent < threshold / 2 else { return false }
        let quietNs = UInt64(quietMs) * 1_000_000
        let elapsedNs = UInt64(now.timeIntervalSince(lastActivityTime) * 1_000_000_000)
        return elapsedNs >= quietNs
    }
}
