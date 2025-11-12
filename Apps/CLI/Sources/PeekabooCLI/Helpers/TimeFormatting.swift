import Foundation
import PeekabooCore

// MARK: - Time Formatting Helpers

// Re-export the formatDuration function from PeekabooCore for backward compatibility
public func formatDuration(_ seconds: TimeInterval) -> String {
    PeekabooCore.formatDuration(seconds)
}

/// Format a date as a human-readable time ago string
public func formatTimeAgo(_ date: Date) -> String {
    let now = Date()
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
