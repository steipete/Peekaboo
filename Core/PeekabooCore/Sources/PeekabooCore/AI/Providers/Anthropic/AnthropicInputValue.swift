import Foundation

/// Type-safe input value for Anthropic tool use
public enum AnthropicInputValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnthropicInputValue])
    case object([String: AnthropicInputValue])
    case null
    
    // MARK: - Codable
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self = .null
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let array = try? container.decode([AnthropicInputValue].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: AnthropicInputValue].self) {
            self = .object(dict)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnthropicInputValue")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .array(let values):
            try container.encode(values)
        case .object(let dict):
            try container.encode(dict)
        case .null:
            try container.encodeNil()
        }
    }
    
    // MARK: - Conversion
    
    /// Convert from Any value (for migration)
    public init?(from value: Any) {
        switch value {
        case let string as String:
            self = .string(string)
        case let int as Int:
            self = .int(int)
        case let double as Double:
            self = .double(double)
        case let bool as Bool:
            self = .bool(bool)
        case let array as [Any]:
            let values = array.compactMap { AnthropicInputValue(from: $0) }
            if values.count == array.count {
                self = .array(values)
            } else {
                return nil
            }
        case let dict as [String: Any]:
            var values: [String: AnthropicInputValue] = [:]
            for (key, val) in dict {
                if let inputValue = AnthropicInputValue(from: val) {
                    values[key] = inputValue
                } else {
                    return nil
                }
            }
            self = .object(values)
        case is NSNull:
            self = .null
        default:
            return nil
        }
    }
    
    /// Convert to Any (for JSON serialization)
    public func toAny() -> Any {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .bool(let value):
            return value
        case .array(let values):
            return values.map { $0.toAny() }
        case .object(let dict):
            return dict.mapValues { $0.toAny() }
        case .null:
            return NSNull()
        }
    }
}

/// Type-safe property schema for Anthropic JSON Schema
public struct AnthropicPropertySchema: Codable, Sendable {
    public let type: String
    public let description: String?
    public let `enum`: [String]?
    public let items: Box<AnthropicPropertySchema>?
    public let properties: [String: AnthropicPropertySchema]?
    public let required: [String]?
    
    public init(
        type: String,
        description: String? = nil,
        enum enumValues: [String]? = nil,
        items: AnthropicPropertySchema? = nil,
        properties: [String: AnthropicPropertySchema]? = nil,
        required: [String]? = nil
    ) {
        self.type = type
        self.description = description
        self.enum = enumValues
        self.items = items.map(Box.init)
        self.properties = properties
        self.required = required
    }
}