// AnyCodable.swift - Type-erased Codable wrapper for mixed-type payloads

import Foundation

// MARK: - AnyCodable for mixed-type payloads or attributes

/// A type-erased wrapper that enables encoding and decoding of heterogeneous values.
///
/// AnyCodable provides a way to work with JSON or other encoded data that contains
/// mixed types (strings, numbers, booleans, arrays, dictionaries) without knowing
/// the exact types at compile time. This is particularly useful for handling
/// accessibility attributes which can have various value types.
///
/// The struct is marked as @unchecked Sendable because the underlying value
/// property is immutable after initialization, making it safe for concurrent access.
public struct AnyCodable: Codable, @unchecked Sendable, Equatable {
    // MARK: Lifecycle

    public init(_ value: (some Any)?) {
        self.value = value ?? ()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = ()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map(\.value)
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }

    // MARK: Public

    public let value: Any

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if value is () { // Our nil marker for explicit nil
            try container.encodeNil()
            return
        }
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            if let codableValue = value as? Encodable {
                // If the value conforms to Encodable, let it encode itself using the provided encoder.
                // This is the most flexible approach as the Encodable type can use any container type it needs.
                try codableValue.encode(to: encoder)
            } else if CFGetTypeID(value as CFTypeRef) == CFNullGetTypeID() {
                try container.encodeNil()
            } else {
                throw EncodingError.invalidValue(
                    value,
                    EncodingError.Context(
                        codingPath: [],
                        debugDescription: "AnyCodable value (\(type(of: value))) cannot be encoded and does not conform to Encodable."
                    )
                )
            }
        }
    }
    
    // MARK: - Equatable Implementation
    
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        // Handle nil marker case
        if lhs.value is (), rhs.value is () {
            return true
        }
        if lhs.value is () || rhs.value is () {
            return false
        }
        
        // Compare based on type
        switch (lhs.value, rhs.value) {
        case let (lhsBool as Bool, rhsBool as Bool):
            return lhsBool == rhsBool
        case let (lhsInt as Int, rhsInt as Int):
            return lhsInt == rhsInt
        case let (lhsDouble as Double, rhsDouble as Double):
            return lhsDouble == rhsDouble
        case let (lhsString as String, rhsString as String):
            return lhsString == rhsString
        case let (lhsArray as [Any], rhsArray as [Any]):
            guard lhsArray.count == rhsArray.count else { return false }
            for (lhsElement, rhsElement) in zip(lhsArray, rhsArray) {
                if AnyCodable(lhsElement) != AnyCodable(rhsElement) {
                    return false
                }
            }
            return true
        case let (lhsDict as [String: Any], rhsDict as [String: Any]):
            guard lhsDict.count == rhsDict.count else { return false }
            for (key, lhsValue) in lhsDict {
                guard let rhsValue = rhsDict[key] else { return false }
                if AnyCodable(lhsValue) != AnyCodable(rhsValue) {
                    return false
                }
            }
            return true
        default:
            // For types we don't specifically handle, try to compare as strings
            return String(describing: lhs.value) == String(describing: rhs.value)
        }
    }
}

// Helper struct for AnyCodable to properly encode intermediate Encodable values
// This might not be necessary if the direct (value as! Encodable).encode(to: encoder) works.
struct AnyCodablePośrednik<T: Encodable>: Encodable {
    // MARK: Lifecycle

    init(_ value: T) { self.value = value }

    // MARK: Internal

    let value: T

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

// Helper protocol to check if a type is Optional
private protocol OptionalProtocol {
    static func isOptional() -> Bool
}

extension Optional: OptionalProtocol {
    static func isOptional() -> Bool {
        true
    }
}
