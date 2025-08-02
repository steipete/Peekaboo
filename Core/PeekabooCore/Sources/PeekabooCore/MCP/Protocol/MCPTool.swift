import Foundation
import MCP

/// Protocol defining the interface for MCP tools
public protocol MCPTool: Sendable {
    /// The unique name of the tool
    var name: String { get }
    
    /// A human-readable description of what the tool does
    var description: String { get }
    
    /// JSON Schema defining the input parameters
    var inputSchema: Value { get }
    
    /// Execute the tool with the given arguments
    func execute(arguments: ToolArguments) async throws -> ToolResponse
}

/// Wrapper for tool arguments received from MCP
public struct ToolArguments: Sendable {
    private let raw: Value
    
    public init(raw: [String: Any]) {
        // Convert [String: Any] to Value for Sendable compliance
        self.raw = .object(raw.mapValues { convertToValue($0) })
    }
    
    public init(value: Value) {
        self.raw = value
    }
    
    /// Decode arguments into a specific type
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let data = try JSONEncoder().encode(raw)
        return try JSONDecoder().decode(type, from: data)
    }
    
    /// Get a specific value by key
    public func getValue(for key: String) -> Value? {
        if case let .object(dict) = raw {
            return dict[key]
        }
        return nil
    }
    
    /// Check if arguments are empty
    public var isEmpty: Bool {
        if case let .object(dict) = raw {
            return dict.isEmpty
        }
        return true
    }
    
    // MARK: - Convenience methods for common types
    
    /// Get a string value
    public func getString(_ key: String) -> String? {
        guard let value = getValue(for: key) else { return nil }
        switch value {
        case .string(let str):
            return str
        case .int(let num):
            return String(num)
        case .double(let num):
            return String(num)
        case .bool(let bool):
            return String(bool)
        default:
            return nil
        }
    }
    
    /// Get a number (Int or Double) as Double
    public func getNumber(_ key: String) -> Double? {
        guard let value = getValue(for: key) else { return nil }
        switch value {
        case .int(let num):
            return Double(num)
        case .double(let num):
            return num
        case .string(let str):
            return Double(str)
        default:
            return nil
        }
    }
    
    /// Get an integer value
    public func getInt(_ key: String) -> Int? {
        guard let value = getValue(for: key) else { return nil }
        switch value {
        case .int(let num):
            return num
        case .double(let num):
            return Int(num)
        case .string(let str):
            return Int(str)
        default:
            return nil
        }
    }
    
    /// Get a boolean value
    public func getBool(_ key: String) -> Bool? {
        guard let value = getValue(for: key) else { return nil }
        switch value {
        case .bool(let bool):
            return bool
        case .string(let str):
            return ["true", "yes", "1"].contains(str.lowercased())
        case .int(let num):
            return num != 0
        default:
            return nil
        }
    }
    
    /// Get an array of strings
    public func getStringArray(_ key: String) -> [String]? {
        guard let value = getValue(for: key) else { return nil }
        if case .array(let array) = value {
            return array.compactMap { element in
                if case .string(let str) = element {
                    return str
                }
                return nil
            }
        }
        return nil
    }
}

// Helper function to convert Any to Value
private func convertToValue(_ value: Any) -> Value {
    switch value {
    case let string as String:
        return .string(string)
    case let number as Int:
        return .int(number)
    case let number as Double:
        return .double(number)
    case let bool as Bool:
        return .bool(bool)
    case let array as [Any]:
        return .array(array.map { convertToValue($0) })
    case let dict as [String: Any]:
        return .object(dict.mapValues { convertToValue($0) })
    case is NSNull:
        return .null
    default:
        // Fallback for unexpected types
        return .string(String(describing: value))
    }
}

/// Response from tool execution
public struct ToolResponse: Sendable {
    public let content: [MCP.Tool.Content]
    public let isError: Bool
    public let meta: Value?
    
    public init(content: [MCP.Tool.Content], isError: Bool = false, meta: Value? = nil) {
        self.content = content
        self.isError = isError
        self.meta = meta
    }
    
    /// Create a text response
    public static func text(_ text: String, meta: Value? = nil) -> ToolResponse {
        ToolResponse(
            content: [.text(text)],
            isError: false,
            meta: meta
        )
    }
    
    /// Create an error response
    public static func error(_ message: String, meta: Value? = nil) -> ToolResponse {
        ToolResponse(
            content: [.text(message)],
            isError: true,
            meta: meta
        )
    }
    
    /// Create an image response
    public static func image(data: Data, mimeType: String = "image/png", meta: Value? = nil) -> ToolResponse {
        ToolResponse(
            content: [.image(data: data.base64EncodedString(), mimeType: mimeType, metadata: nil)],
            isError: false,
            meta: meta
        )
    }
    
    /// Create a multi-content response
    public static func multiContent(_ contents: [MCP.Tool.Content], meta: Value? = nil) -> ToolResponse {
        ToolResponse(
            content: contents,
            isError: false,
            meta: meta
        )
    }
}

// Type alias for convenience
public typealias Content = MCP.Tool.Content