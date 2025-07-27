import Foundation

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
        logger?.error("\(context): \(self.localizedDescription)", error: self)
        
        // Try to preserve specific PeekabooError types
        if let peekabooError = self as? PeekabooError {
            return peekabooError
        }
        
        // Convert common errors to specific types
        if (self as NSError).domain == NSURLErrorDomain {
            return .networkError(self.localizedDescription)
        }
        
        // Default to operation error
        return .operationError("\(context): \(self.localizedDescription)")
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

// MARK: - Parameter Validation

extension Dictionary where Key == String, Value == AnyCodable {
    /// Extract a required string parameter
    public func requireString(_ key: String) throws -> String {
        guard let value = self[key]?.stringValue else {
            throw PeekabooError.invalidInput("Missing required parameter: \(key)")
        }
        return value
    }
    
    /// Extract a required integer parameter
    public func requireInt(_ key: String) throws -> Int {
        guard let value = self[key]?.intValue else {
            throw PeekabooError.invalidInput("Missing required parameter: \(key)")
        }
        return value
    }
    
    /// Extract an optional string parameter
    public func optionalString(_ key: String) -> String? {
        self[key]?.stringValue
    }
    
    /// Extract an optional boolean parameter with default
    public func optionalBool(_ key: String, default defaultValue: Bool = false) -> Bool {
        self[key]?.boolValue ?? defaultValue
    }
    
    /// Extract an optional integer parameter with default
    public func optionalInt(_ key: String, default defaultValue: Int) -> Int {
        self[key]?.intValue ?? defaultValue
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
    /// Find a window by application name (case-insensitive)
    public func findWindow(byAppName appName: String) throws -> WindowInfo {
        guard let window = first(where: { 
            $0.applicationName.lowercased() == appName.lowercased() 
        }) else {
            throw PeekabooError.windowNotFound(criteria: "application '\(appName)'")
        }
        return window
    }
    
    /// Find a window by title (partial match, case-insensitive)
    public func findWindow(byTitle title: String) throws -> WindowInfo {
        guard let window = first(where: { 
            $0.title.lowercased().contains(title.lowercased()) 
        }) else {
            throw PeekabooError.windowNotFound(criteria: "title containing '\(title)'")
        }
        return window
    }
    
    /// Find a window by ID
    public func findWindow(byID windowID: CGWindowID) throws -> WindowInfo {
        guard let window = first(where: { $0.windowID == windowID }) else {
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
            $0.name.lowercased() == name.lowercased() 
        })
    }
    
    /// Find an application by bundle ID
    public func findApp(byBundleID bundleID: String) -> ApplicationInfo? {
        first(where: { $0.bundleIdentifier == bundleID })
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