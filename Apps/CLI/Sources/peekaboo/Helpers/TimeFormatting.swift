import Foundation
import PeekabooCore

// Re-export the formatDuration function from PeekabooCore for backward compatibility
public func formatDuration(_ seconds: TimeInterval) -> String {
    PeekabooCore.formatDuration(seconds)
}
