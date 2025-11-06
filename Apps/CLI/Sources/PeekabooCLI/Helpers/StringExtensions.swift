import Foundation

// MARK: - String Extensions

extension String {
    /// Truncates a string to the specified length, adding ellipsis if needed
    func truncated(to length: Int) -> String {
        // Truncates a string to the specified length, adding ellipsis if needed
        if self.count <= length {
            return self
        }
        return String(self.prefix(length - 3)) + "..."
    }
}
