import Foundation

/// Formats a time duration into a human-readable string
/// - Parameter seconds: The duration in seconds
/// - Returns: A formatted string like "123µs", "45ms", "2.3s", or "1min 30s"
public func formatDuration(_ seconds: TimeInterval) -> String {
    if seconds < 0.001 {
        return String(format: "%.0fµs", seconds * 1_000_000)
    } else if seconds < 1.0 {
        return String(format: "%.0fms", seconds * 1000)
    } else if seconds < 60.0 {
        return String(format: "%.1fs", seconds)
    } else {
        let minutes = Int(seconds / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%dmin %ds", minutes, remainingSeconds)
    }
}