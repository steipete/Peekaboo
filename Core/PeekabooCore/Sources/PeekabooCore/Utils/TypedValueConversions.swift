//
//  TypedValueConversions.swift
//  PeekabooCore
//

import Foundation

// MARK: - Migration Helpers

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
extension TypedValue {
    // MARK: - Encoding Helpers

    /// Encode a value into a container with type checking
    public static func encode(_ value: Any, to container: inout some UnkeyedEncodingContainer) throws {
        // Encode a value into a container with type checking
        let typedValue = try TypedValue.fromJSON(value)
        switch typedValue {
        case .null:
            try container.encodeNil()
        case let .bool(v):
            try container.encode(v)
        case let .int(v):
            try container.encode(v)
        case let .double(v):
            try container.encode(v)
        case let .string(v):
            try container.encode(v)
        case let .array(values):
            var nestedContainer = container.nestedUnkeyedContainer()
            for element in values {
                try self.encode(element.toJSON(), to: &nestedContainer)
            }
        case let .object(dict):
            var nestedContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self)
            for (key, val) in dict {
                try nestedContainer.encode(val, forKey: DynamicCodingKey(stringValue: key))
            }
        }
    }

    /// Encode a dictionary with heterogeneous values
    public static func encodeDictionary(
        _ dict: [String: Any],
        to container: inout KeyedEncodingContainer<DynamicCodingKey>) throws
    {
        // Encode a dictionary with heterogeneous values
        for (key, value) in dict {
            let typedValue = try TypedValue.fromJSON(value)
            let codingKey = DynamicCodingKey(stringValue: key)

            switch typedValue {
            case .null:
                try container.encodeNil(forKey: codingKey)
            case let .bool(v):
                try container.encode(v, forKey: codingKey)
            case let .int(v):
                try container.encode(v, forKey: codingKey)
            case let .double(v):
                try container.encode(v, forKey: codingKey)
            case let .string(v):
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
    public static func decode(from container: SingleValueDecodingContainer) throws -> TypedValue {
        // Decode from a single value container
        if container.decodeNil() {
            return .null
        } else if let bool = try? container.decode(Bool.self) {
            return .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            return .int(int)
        } else if let double = try? container.decode(Double.self) {
            if double.truncatingRemainder(dividingBy: 1) == 0,
               double >= Double(Int.min),
               double <= Double(Int.max)
            {
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
                debugDescription: "Unable to decode TypedValue")
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
        // Capture the provided string key while marking the integer form as unavailable.
        self.stringValue = stringValue
        self.intValue = nil
    }

    public init?(intValue: Int) {
        // Store the integer key while also keeping the string representation in sync.
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

// MARK: - Legacy Support

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
extension TypedValue {
    /// Convert from AnyCodable for migration purposes
    /// This will be removed once AnyCodable is fully replaced
    public static func fromAnyCodable(_ anyCodable: Any) throws -> TypedValue {
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
            try self.value.encode(to: encoder)
        }
    }
}

// MARK: - Type Checking Utilities

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
extension TypedValue {
    /// Check if the value matches a specific type
    public func matches(_ type: (some Any).Type) -> Bool {
        switch self {
        case .bool where type == Bool.self:
            true
        case .int where type == Int.self:
            true
        case .double where type == Double.self || type == Float.self:
            true
        case .string where type == String.self:
            true
        case .array where type == [TypedValue].self || type == [Any].self:
            true
        case .object where type == [String: TypedValue].self || type == [String: Any].self:
            true
        case .null where type == NSNull.self || type == Void.self:
            true
        default:
            false
        }
    }

    /// Try to cast the value to a specific type
    public func cast<T>(to type: T.Type) -> T? {
        switch self {
        case let .bool(v) where type == Bool.self:
            v as? T
        case let .int(v) where type == Int.self:
            v as? T
        case let .double(v) where type == Double.self:
            v as? T
        case let .string(v) where type == String.self:
            v as? T
        case let .array(v) where type == [TypedValue].self:
            v as? T
        case let .object(v) where type == [String: TypedValue].self:
            v as? T
        default:
            nil
        }
    }
}

// MARK: - Batch Operations

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
extension [TypedValue] {
    /// Convert array of TypedValues to JSON array
    public func toJSONArray() -> [Any] {
        // Convert array of TypedValues to JSON array
        map { $0.toJSON() }
    }

    /// Create from JSON array
    public static func fromJSONArray(_ jsonArray: [Any]) throws -> [TypedValue] {
        // Create from JSON array
        try jsonArray.map { try TypedValue.fromJSON($0) }
    }
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
extension [String: TypedValue] {
    /// Convert dictionary of TypedValues to JSON dictionary
    public func toJSONDictionary() -> [String: Any] {
        // Convert dictionary of TypedValues to JSON dictionary
        mapValues { $0.toJSON() }
    }

    /// Create from JSON dictionary
    public static func fromJSONDictionary(_ jsonDict: [String: Any]) throws -> [String: TypedValue] {
        // Create from JSON dictionary
        try jsonDict.mapValues { try TypedValue.fromJSON($0) }
    }
}
