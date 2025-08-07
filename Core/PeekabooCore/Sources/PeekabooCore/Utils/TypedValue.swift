//
//  TypedValue.swift
//  PeekabooCore
//

import Foundation

/// A type-safe enum for representing heterogeneous values in a strongly-typed manner.
/// This replaces AnyCodable and other type-erased patterns throughout the codebase.
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
public enum TypedValue: Codable, Sendable, Equatable, Hashable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([TypedValue])
    case object([String: TypedValue])
    
    // MARK: - Type Information
    
    /// The type category of this value
    public enum ValueType: String, Codable, Sendable {
        case null
        case boolean
        case integer
        case number
        case string
        case array
        case object
    }
    
    /// Returns the type of this value
    public var valueType: ValueType {
        switch self {
        case .null: return .null
        case .bool: return .boolean
        case .int: return .integer
        case .double: return .number
        case .string: return .string
        case .array: return .array
        case .object: return .object
        }
    }
    
    // MARK: - Convenience Accessors
    
    /// Returns the value as a Bool if it is one
    public var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }
    
    /// Returns the value as an Int if it is one
    public var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }
    
    /// Returns the value as a Double, converting from Int if needed
    public var doubleValue: Double? {
        switch self {
        case .double(let value): return value
        case .int(let value): return Double(value)
        default: return nil
        }
    }
    
    /// Returns the value as a String if it is one
    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }
    
    /// Returns the value as an array if it is one
    public var arrayValue: [TypedValue]? {
        if case .array(let value) = self { return value }
        return nil
    }
    
    /// Returns the value as an object/dictionary if it is one
    public var objectValue: [String: TypedValue]? {
        if case .object(let value) = self { return value }
        return nil
    }
    
    /// Returns true if this is a null value
    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }
    
    // MARK: - JSON Conversion
    
    /// Convert to a JSON-compatible Any type
    public func toJSON() -> Any {
        switch self {
        case .null:
            return NSNull()
        case .bool(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .string(let value):
            return value
        case .array(let values):
            return values.map { $0.toJSON() }
        case .object(let dict):
            return dict.mapValues { $0.toJSON() }
        }
    }
    
    /// Create from a JSON-compatible Any type
    public static func fromJSON(_ json: Any) throws -> TypedValue {
        switch json {
        case is NSNull:
            return .null
        case let bool as Bool:
            return .bool(bool)
        case let int as Int:
            return .int(int)
        case let double as Double:
            // Check if it's actually an integer value
            if double.truncatingRemainder(dividingBy: 1) == 0 && 
               double >= Double(Int.min) && 
               double <= Double(Int.max) {
                return .int(Int(double))
            }
            return .double(double)
        case let string as String:
            return .string(string)
        case let array as [Any]:
            let values = try array.map { try TypedValue.fromJSON($0) }
            return .array(values)
        case let dict as [String: Any]:
            let values = try dict.mapValues { try TypedValue.fromJSON($0) }
            return .object(values)
        default:
            throw TypedValueError.unsupportedType(type: String(describing: type(of: json)))
        }
    }
    
    // MARK: - Codable Implementation
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            // Check if it's actually an integer
            if double.truncatingRemainder(dividingBy: 1) == 0 && 
               double >= Double(Int.min) && 
               double <= Double(Int.max) {
                self = .int(Int(double))
            } else {
                self = .double(double)
            }
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([TypedValue].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: TypedValue].self) {
            self = .object(dict)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode TypedValue from container"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let values):
            try container.encode(values)
        case .object(let dict):
            try container.encode(dict)
        }
    }
}

// MARK: - Error Types

public enum TypedValueError: LocalizedError {
    case unsupportedType(type: String)
    case conversionFailed(from: String, to: String)
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedType(let type):
            return "Unsupported type for TypedValue: \(type)"
        case .conversionFailed(let from, let to):
            return "Failed to convert from \(from) to \(to)"
        }
    }
}

// MARK: - Convenience Initializers

extension TypedValue {
    /// Create from any Encodable value
    public init<T: Encodable>(from value: T) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        let json = try JSONSerialization.jsonObject(with: data)
        self = try TypedValue.fromJSON(json)
    }
    
    /// Decode into a specific Decodable type
    public func decode<T: Decodable>(as type: T.Type) throws -> T {
        let json = self.toJSON()
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }
}

// MARK: - Collection Helpers

extension TypedValue {
    /// Create from a dictionary with string keys
    public static func fromDictionary(_ dict: [String: Any]) throws -> TypedValue {
        return try fromJSON(dict)
    }
    
    /// Convert to dictionary if this is an object type
    public func toDictionary() throws -> [String: Any] {
        guard case .object(let dict) = self else {
            throw TypedValueError.conversionFailed(from: "\(valueType)", to: "dictionary")
        }
        return dict.mapValues { $0.toJSON() }
    }
}

// MARK: - ExpressibleBy Conformances

extension TypedValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension TypedValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension TypedValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension TypedValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension TypedValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension TypedValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: TypedValue...) {
        self = .array(elements)
    }
}

extension TypedValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, TypedValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}