import Foundation
import PeekabooCore

// MARK: - Time Formatting Helpers

// Re-export the formatDuration function from PeekabooCore for backward compatibility
public func formatDuration(_ seconds: TimeInterval) -> String {
    PeekabooCore.formatDuration(seconds)
}

/// Format a date as a human-readable time ago string
public func formatTimeAgo(_ date: Date, from now: Date = Date()) -> String {
    PeekabooCore.formatTimeAgo(date, from: now)
}
