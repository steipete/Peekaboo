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
    private let raw: [String: Any]
    
    public init(raw: [String: Any]) {
        self.raw = raw
    }
    
    /// Decode arguments into a specific type
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: raw)
        return try JSONDecoder().decode(type, from: data)
    }
    
    /// Get a specific value by key
    public func getValue(for key: String) -> Any? {
        raw[key]
    }
    
    /// Check if arguments are empty
    public var isEmpty: Bool {
        raw.isEmpty
    }
}

/// Response from tool execution
public struct ToolResponse: Sendable {
    public let content: [Content]
    public let isError: Bool
    public let meta: [String: Any]?
    
    public init(content: [Content], isError: Bool = false, meta: [String: Any]? = nil) {
        self.content = content
        self.isError = isError
        self.meta = meta
    }
    
    /// Create a text response
    public static func text(_ text: String, meta: [String: Any]? = nil) -> ToolResponse {
        ToolResponse(
            content: [.text(text)],
            isError: false,
            meta: meta
        )
    }
    
    /// Create an error response
    public static func error(_ message: String, meta: [String: Any]? = nil) -> ToolResponse {
        ToolResponse(
            content: [.text(message)],
            isError: true,
            meta: meta
        )
    }
    
    /// Create an image response
    public static func image(data: Data, mimeType: String = "image/png", meta: [String: Any]? = nil) -> ToolResponse {
        ToolResponse(
            content: [.image(data: data, mimeType: mimeType)],
            isError: false,
            meta: meta
        )
    }
    
    /// Create a multi-content response
    public static func multiContent(_ contents: [Content], meta: [String: Any]? = nil) -> ToolResponse {
        ToolResponse(
            content: contents,
            isError: false,
            meta: meta
        )
    }
}