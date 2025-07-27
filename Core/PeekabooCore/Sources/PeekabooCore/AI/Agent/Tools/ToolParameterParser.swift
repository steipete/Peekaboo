import Foundation

// MARK: - Tool Parameter Parser

/// Type-safe tool parameter parser that replaces AnyCodable-based extraction
@available(macOS 14.0, *)
public struct ToolParameterParser {
    private let jsonData: Data
    private let toolName: String
    
    /// Initialize with JSON string from tool arguments
    public init(jsonString: String, toolName: String) throws {
        guard let data = jsonString.data(using: .utf8) else {
            throw PeekabooError.invalidInput("\(toolName): Invalid JSON string")
        }
        self.jsonData = data
        self.toolName = toolName
    }
    
    /// Initialize with ToolInput
    public init(_ input: ToolInput, toolName: String) throws {
        self.toolName = toolName
        
        switch input {
        case .string(let str):
            guard let data = str.data(using: .utf8) else {
                throw PeekabooError.invalidInput("\(toolName): Invalid JSON string")
            }
            self.jsonData = data
        case .dictionary(let dict):
            self.jsonData = try JSONSerialization.data(withJSONObject: dict)
        case .array(let array):
            self.jsonData = try JSONSerialization.data(withJSONObject: array)
        case .null:
            self.jsonData = "{}".data(using: .utf8)!
        }
    }
    
    /// Decode the entire parameters as a specific type
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: jsonData)
        } catch {
            throw PeekabooError.invalidInput("\(toolName): Failed to decode parameters - \(error)")
        }
    }
    
    /// Parse as dictionary for dynamic access
    public func asDictionary() throws -> [String: Any] {
        guard let dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw PeekabooError.invalidInput("\(toolName): Parameters must be an object")
        }
        return dict
    }
    
    /// Get a required string parameter
    public func string(_ key: String) throws -> String {
        let dict = try asDictionary()
        guard let value = dict[key] as? String else {
            throw PeekabooError.invalidInput("\(toolName): '\(key)' parameter is required")
        }
        return value
    }
    
    /// Get an optional string parameter
    public func string(_ key: String, default defaultValue: String? = nil) throws -> String? {
        let dict = try asDictionary()
        return dict[key] as? String ?? defaultValue
    }
    
    /// Get a required integer parameter
    public func int(_ key: String) throws -> Int {
        let dict = try asDictionary()
        if let value = dict[key] as? Int {
            return value
        }
        // Try to convert from Double
        if let doubleValue = dict[key] as? Double {
            return Int(doubleValue)
        }
        throw PeekabooError.invalidInput("\(toolName): '\(key)' parameter is required as integer")
    }
    
    /// Get an optional integer parameter
    public func int(_ key: String, default defaultValue: Int? = nil) throws -> Int? {
        let dict = try asDictionary()
        if let value = dict[key] as? Int {
            return value
        }
        if let doubleValue = dict[key] as? Double {
            return Int(doubleValue)
        }
        return defaultValue
    }
    
    /// Get an optional boolean parameter
    public func bool(_ key: String, default defaultValue: Bool = false) throws -> Bool {
        let dict = try asDictionary()
        return dict[key] as? Bool ?? defaultValue
    }
    
    /// Get an optional array of strings
    public func stringArray(_ key: String) throws -> [String]? {
        let dict = try asDictionary()
        guard let array = dict[key] as? [Any] else { return nil }
        return array.compactMap { $0 as? String }
    }
    
    /// Get an optional double parameter
    public func double(_ key: String, default defaultValue: Double? = nil) throws -> Double? {
        let dict = try asDictionary()
        if let value = dict[key] as? Double {
            return value
        }
        if let intValue = dict[key] as? Int {
            return Double(intValue)
        }
        return defaultValue
    }
}

// MARK: - Strongly Typed Tool Parameters

/// Protocol for strongly typed tool parameters
public protocol ToolParametersProtocol: Codable {
    /// Validate the parameters after decoding
    func validate() throws
}

/// Default implementation that doesn't require validation
public extension ToolParametersProtocol {
    func validate() throws {
        // No validation by default
    }
}

// MARK: - Common Parameter Types

/// Parameters for text-based tools
public struct TextToolParameters: ToolParametersProtocol {
    public let text: String
    public let options: TextOptions?
    
    public struct TextOptions: Codable {
        public let caseSensitive: Bool?
        public let regex: Bool?
    }
}

/// Parameters for coordinate-based tools
public struct CoordinateToolParameters: ToolParametersProtocol {
    public let x: Double
    public let y: Double
    
    public func validate() throws {
        if x < 0 || y < 0 {
            throw PeekabooError.invalidInput("Coordinates must be non-negative")
        }
    }
}

/// Parameters for window management tools
public struct WindowToolParameters: ToolParametersProtocol {
    public let windowId: String?
    public let appName: String?
    public let title: String?
    
    public func validate() throws {
        if windowId == nil && appName == nil && title == nil {
            throw PeekabooError.invalidInput("At least one of windowId, appName, or title must be provided")
        }
    }
}

/// Parameters for file-based tools
public struct FileToolParameters: ToolParametersProtocol {
    public let path: String
    public let format: String?
}

/// Parameters for app-based tools
public struct AppToolParameters: ToolParametersProtocol {
    public let appName: String
    public let action: String?
}