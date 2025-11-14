import Foundation

/// Formats a time duration into a human-readable string
/// - Parameter seconds: The duration in seconds
/// - Returns: A formatted string like "123µs", "45ms", "2.3s", or "1m 30s"
public func formatDuration(_ seconds: TimeInterval) -> String {
    // Formats a time duration into a human-readable string
    if seconds < 0.001 {
        return String(format: "%.0fµs", seconds * 1_000_000)
    } else if seconds < 1.0 {
        return String(format: "%.0fms", seconds * 1000)
    } else if seconds < 60.0 {
        return String(format: "%.1fs", seconds)
    } else {
        let minutes = Int(seconds / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%dm %ds", minutes, remainingSeconds)
    }
}

/// Formats a date relative to now
/// - Parameters:
///   - date: The date to format
///   - now: The reference date (defaults to current date)
/// - Returns: A formatted string like "just now", "5 minutes ago", "2 hours ago", etc.
public func formatTimeAgo(_ date: Date, from now: Date = Date()) -> String {
    // Formats a date relative to now
    let interval = now.timeIntervalSince(date)

    if interval < 60 {
        return "just now"
    } else if interval < 3600 {
        let minutes = Int(interval / 60)
        return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
    } else if interval < 86400 {
        let hours = Int(interval / 3600)
        return "\(hours) hour\(hours == 1 ? "" : "s") ago"
    } else {
        let days = Int(interval / 86400)
        return "\(days) day\(days == 1 ? "" : "s") ago"
    }
}
