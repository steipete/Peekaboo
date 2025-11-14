import Foundation

/// Helper for generating and managing correlation IDs
public enum CorrelationID {
    /// Generate a new correlation ID
    public static func generate() -> String {
        // Generate a new correlation ID
        UUID().uuidString
    }

    /// Generate a correlation ID with a prefix
    public static func generate(prefix: String) -> String {
        // Generate a correlation ID with a prefix
        "\(prefix)-\(UUID().uuidString)"
    }

    /// Extract the prefix from a correlation ID
    public static func extractPrefix(from correlationId: String) -> String? {
        // Extract the prefix from a correlation ID
        let components = correlationId.split(separator: "-", maxSplits: 1)
        return components.count > 1 ? String(components[0]) : nil
    }
}

/// Extension to make it easier to add correlation IDs to metadata
extension [String: Any] {
    /// Add a correlation ID to the metadata
    public mutating func addCorrelationId(_ correlationId: String?) {
        // Add a correlation ID to the metadata
        if let id = correlationId {
            self["correlationId"] = id
        }
    }

    /// Create a new dictionary with the correlation ID added
    public func withCorrelationId(_ correlationId: String?) -> [String: Any] {
        // Create a new dictionary with the correlation ID added
        var newDict = self
        newDict.addCorrelationId(correlationId)
        return newDict
    }
}
