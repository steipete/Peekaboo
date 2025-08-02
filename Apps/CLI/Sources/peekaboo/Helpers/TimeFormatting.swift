import Foundation
import PeekabooCore
// SUCCESS: Poltergeist is now working correctly! ✅

// Re-export the formatDuration function from PeekabooCore for backward compatibility
public func formatDuration(_ seconds: TimeInterval) -> String {
    return PeekabooCore.formatDuration(seconds)
}
