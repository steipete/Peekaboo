import CoreGraphics
import Foundation

// MARK: - JSON Coding

/// Shared JSON encoder/decoder configuration for consistent serialization
public enum JSONCoding {
    /// Shared JSON encoder with pretty printing and sorted keys
    public static let encoder: JSONEncoder = makeEncoder()

    /// Shared JSON decoder with consistent configuration
    public static let decoder: JSONDecoder = makeDecoder()

    /// Create a configured encoder instance
    public nonisolated static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// Create a configured decoder instance
    public nonisolated static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

// MARK: - Error Extensions

extension Error {
    /// Convert any error to a PeekabooError with context
    public func asPeekabooError(
        context: String) -> PeekabooError
    {
        // Try to preserve specific PeekabooError types
        if let peekabooError = self as? PeekabooError {
            return peekabooError
        }

        // Convert common errors to specific types
        if (self as NSError).domain == NSURLErrorDomain {
            return .networkError(self.localizedDescription)
        }

        // Default to operation error
        return .operationError(message: "\(context): \(self.localizedDescription)")
    }
}

// MARK: - Async Operation Helpers

/// Perform an async operation with consistent error handling
public func performOperation<T>(
    _ operation: @Sendable () async throws -> T,
    errorContext: String) async throws -> T
{
    do {
        return try await operation()
    } catch {
        throw error.asPeekabooError(context: errorContext)
    }
}

// MARK: - Path Utilities

extension String {
    /// Expand tilde and return absolute path
    public var expandedPath: String {
        (self as NSString).expandingTildeInPath
    }

    /// Convert to file URL
    public var fileURL: URL {
        URL(fileURLWithPath: self.expandedPath)
    }
}

// WindowInfo and ApplicationInfo extensions removed - these are higher-level types in PeekabooCore

// MARK: - Time Utilities

extension TimeInterval {
    /// Convert to nanoseconds for Task.sleep
    public var nanoseconds: UInt64 {
        UInt64(self * 1_000_000_000)
    }

    /// Common sleep durations
    public static let shortDelay: TimeInterval = 0.1
    public static let mediumDelay: TimeInterval = 0.5
    public static let longDelay: TimeInterval = 1.0
}
