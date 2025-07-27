import Foundation
import CoreGraphics

// MARK: - JSON Coding

/// Shared JSON encoder/decoder configuration for consistent serialization
public enum JSONCoding {
    /// Shared JSON encoder with pretty printing and sorted keys
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    /// Shared JSON decoder with consistent configuration
    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

// MARK: - Error Extensions

extension Error {
    /// Convert any error to a PeekabooError with context
    public func asPeekabooError(
        context: String,
        logger: LoggingServiceProtocol? = nil
    ) -> PeekabooError {
        logger?.error("\(context): \(self.localizedDescription)", category: "error-conversion")
        
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
    _ operation: () async throws -> T,
    errorContext: String,
    logger: LoggingServiceProtocol? = nil
) async throws -> T {
    do {
        return try await operation()
    } catch {
        throw error.asPeekabooError(context: errorContext, logger: logger)
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

// MARK: - Window Finding

extension Array where Element == WindowInfo {
    // Note: WindowInfo doesn't have an applicationName property, so this method can't be implemented
    // It would need to be implemented at a higher level where we have access to both window and app info
    
    /// Find a window by title (partial match, case-insensitive)
    public func findWindow(byTitle title: String) throws -> WindowInfo {
        guard let window = first(where: { 
            $0.window_title.lowercased().contains(title.lowercased()) 
        }) else {
            throw PeekabooError.windowNotFound(criteria: "title containing '\(title)'")
        }
        return window
    }
    
    /// Find a window by ID
    public func findWindow(byID windowID: CGWindowID) throws -> WindowInfo {
        guard let window = first(where: { $0.window_id == UInt32(windowID) }) else {
            throw PeekabooError.windowNotFound(criteria: "ID \(windowID)")
        }
        return window
    }
}

// MARK: - Application Finding

extension Array where Element == ApplicationInfo {
    /// Find an application by name (case-insensitive)
    public func findApp(byName name: String) -> ApplicationInfo? {
        first(where: { 
            $0.app_name.lowercased() == name.lowercased() 
        })
    }
    
    /// Find an application by bundle ID
    public func findApp(byBundleID bundleID: String) -> ApplicationInfo? {
        first(where: { $0.bundle_id == bundleID })
    }
}

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