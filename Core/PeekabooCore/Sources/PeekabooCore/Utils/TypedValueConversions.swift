//
//  TypedValueConversions.swift
//  PeekabooCore
//

import Foundation

// MARK: - Migration Helpers

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
public extension TypedValue {
    
    // MARK: - Encoding Helpers
    
    /// Encode a value into a container with type checking
    static func encode<T>(_ value: Any, to container: inout T) throws where T: UnkeyedEncodingContainer {
        let typedValue = try TypedValue.fromJSON(value)
        switch typedValue {
        case .null:
            try container.encodeNil()
        case .bool(let v):
            try container.encode(v)
        case .int(let v):
            try container.encode(v)
        case .double(let v):
            try container.encode(v)
        case .string(let v):
            try container.encode(v)
        case .array(let values):
            var nestedContainer = container.nestedUnkeyedContainer()
            for element in values {
                try encode(element.toJSON(), to: &nestedContainer)
            }
        case .object(let dict):
            var nestedContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self)
            for (key, val) in dict {
                try nestedContainer.encode(val, forKey: DynamicCodingKey(stringValue: key))
            }
        }
    }
    
    /// Encode a dictionary with heterogeneous values
    static func encodeDictionary(_ dict: [String: Any], to container: inout KeyedEncodingContainer<DynamicCodingKey>) throws {
        for (key, value) in dict {
            let typedValue = try TypedValue.fromJSON(value)
            let codingKey = DynamicCodingKey(stringValue: key)
            
            switch typedValue {
            case .null:
                try container.encodeNil(forKey: codingKey)
            case .bool(let v):
                try container.encode(v, forKey: codingKey)
            case .int(let v):
                try container.encode(v, forKey: codingKey)
            case .double(let v):
                try container.encode(v, forKey: codingKey)
            case .string(let v):
                try container.encode(v, forKey: codingKey)
            case .array:
                var nestedContainer = container.nestedUnkeyedContainer(forKey: codingKey)
                try TypedValue.encode(typedValue.toJSON(), to: &nestedContainer)
            case .object:
                var nestedContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: codingKey)
                if let dictValue = typedValue.objectValue {
                    let jsonDict = dictValue.mapValues { $0.toJSON() }
                    try TypedValue.encodeDictionary(jsonDict, to: &nestedContainer)
                }
            }
        }
    }
    
    // MARK: - Decoding Helpers
    
    /// Decode from a single value container
    static func decode(from container: SingleValueDecodingContainer) throws -> TypedValue {
        if container.decodeNil() {
            return .null
        } else if let bool = try? container.decode(Bool.self) {
            return .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            return .int(int)
        } else if let double = try? container.decode(Double.self) {
            if double.truncatingRemainder(dividingBy: 1) == 0 && 
               double >= Double(Int.min) && 
               double <= Double(Int.max) {
                return .int(Int(double))
            }
            return .double(double)
        } else if let string = try? container.decode(String.self) {
            return .string(string)
        } else if let array = try? container.decode([TypedValue].self) {
            return .array(array)
        } else if let dict = try? container.decode([String: TypedValue].self) {
            return .object(dict)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode TypedValue"
            )
        }
    }
}

// MARK: - Dynamic Coding Key

/// A coding key that can be created from any string at runtime
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
public struct DynamicCodingKey: CodingKey {
    public let stringValue: String
    public let intValue: Int?
    
    public init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    public init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

// MARK: - Legacy Support

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
public extension TypedValue {
    
    /// Convert from AnyCodable for migration purposes
    /// This will be removed once AnyCodable is fully replaced
    static func fromAnyCodable(_ anyCodable: Any) throws -> TypedValue {
        // Extract the underlying value if it's wrapped
        if let codable = anyCodable as? any Codable {
            // Try to get the raw value through encoding/decoding
            let encoder = JSONEncoder()
            let data = try encoder.encode(AnyEncodableWrapper(codable))
            let json = try JSONSerialization.jsonObject(with: data)
            return try TypedValue.fromJSON(json)
        }
        
        // Fallback to direct conversion
        return try TypedValue.fromJSON(anyCodable)
    }
    
    /// Helper to wrap any Encodable for JSON conversion
    private struct AnyEncodableWrapper: Encodable {
        let value: any Encodable
        
        init(_ value: any Encodable) {
            self.value = value
        }
        
        func encode(to encoder: Encoder) throws {
            try value.encode(to: encoder)
        }
    }
}

// MARK: - Type Checking Utilities

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
public extension TypedValue {
    
    /// Check if the value matches a specific type
    func matches<T>(_ type: T.Type) -> Bool {
        switch self {
        case .bool where type == Bool.self:
            return true
        case .int where type == Int.self:
            return true
        case .double where type == Double.self || type == Float.self:
            return true
        case .string where type == String.self:
            return true
        case .array where type == [TypedValue].self || type == [Any].self:
            return true
        case .object where type == [String: TypedValue].self || type == [String: Any].self:
            return true
        case .null where type == NSNull.self || type == Void.self:
            return true
        default:
            return false
        }
    }
    
    /// Try to cast the value to a specific type
    func cast<T>(to type: T.Type) -> T? {
        switch self {
        case .bool(let v) where type == Bool.self:
            return v as? T
        case .int(let v) where type == Int.self:
            return v as? T
        case .double(let v) where type == Double.self:
            return v as? T
        case .string(let v) where type == String.self:
            return v as? T
        case .array(let v) where type == [TypedValue].self:
            return v as? T
        case .object(let v) where type == [String: TypedValue].self:
            return v as? T
        default:
            return nil
        }
    }
}

// MARK: - Batch Operations

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
public extension Array where Element == TypedValue {
    
    /// Convert array of TypedValues to JSON array
    func toJSONArray() -> [Any] {
        return map { $0.toJSON() }
    }
    
    /// Create from JSON array
    static func fromJSONArray(_ jsonArray: [Any]) throws -> [TypedValue] {
        return try jsonArray.map { try TypedValue.fromJSON($0) }
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
public extension Dictionary where Key == String, Value == TypedValue {
    
    /// Convert dictionary of TypedValues to JSON dictionary
    func toJSONDictionary() -> [String: Any] {
        return mapValues { $0.toJSON() }
    }
    
    /// Create from JSON dictionary
    static func fromJSONDictionary(_ jsonDict: [String: Any]) throws -> [String: TypedValue] {
        return try jsonDict.mapValues { try TypedValue.fromJSON($0) }
    }
}