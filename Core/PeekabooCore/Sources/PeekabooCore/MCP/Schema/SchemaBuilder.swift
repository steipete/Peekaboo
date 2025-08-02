import Foundation
import MCP

/// Builder for JSON Schema using MCP's Value type
public enum SchemaBuilder {
    /// Build a JSON Schema for an object
    public static func object(
        properties: [String: Value],
        required: [String] = [],
        description: String? = nil) -> Value
    {
        var schema: [String: Value] = [
            "type": .string("object"),
            "properties": .object(properties),
        ]

        if !required.isEmpty {
            schema["required"] = .array(required.map { .string($0) })
        }

        if let desc = description {
            schema["description"] = .string(desc)
        }

        return .object(schema)
    }

    /// Build a JSON Schema for a string
    public static func string(
        description: String? = nil,
        enum values: [String]? = nil,
        default: String? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil) -> Value
    {
        var schema: [String: Value] = ["type": .string("string")]

        if let desc = description {
            schema["description"] = .string(desc)
        }

        if let values {
            schema["enum"] = .array(values.map { .string($0) })
        }

        if let defaultValue = `default` {
            schema["default"] = .string(defaultValue)
        }

        if let minLen = minLength {
            schema["minLength"] = .int(minLen)
        }

        if let maxLen = maxLength {
            schema["maxLength"] = .int(maxLen)
        }

        return .object(schema)
    }

    /// Build a JSON Schema for a boolean
    public static func boolean(
        description: String? = nil,
        default: Bool? = nil) -> Value
    {
        var schema: [String: Value] = ["type": .string("boolean")]

        if let desc = description {
            schema["description"] = .string(desc)
        }

        if let defaultValue = `default` {
            schema["default"] = .bool(defaultValue)
        }

        return .object(schema)
    }

    /// Build a JSON Schema for a number
    public static func number(
        description: String? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        default: Double? = nil) -> Value
    {
        var schema: [String: Value] = ["type": .string("number")]

        if let desc = description {
            schema["description"] = .string(desc)
        }

        if let min = minimum {
            schema["minimum"] = .double(min)
        }

        if let max = maximum {
            schema["maximum"] = .double(max)
        }

        if let defaultValue = `default` {
            schema["default"] = .double(defaultValue)
        }

        return .object(schema)
    }

    /// Build a JSON Schema for an integer
    public static func integer(
        description: String? = nil,
        minimum: Int? = nil,
        maximum: Int? = nil,
        default: Int? = nil) -> Value
    {
        var schema: [String: Value] = ["type": .string("integer")]

        if let desc = description {
            schema["description"] = .string(desc)
        }

        if let min = minimum {
            schema["minimum"] = .int(min)
        }

        if let max = maximum {
            schema["maximum"] = .int(max)
        }

        if let defaultValue = `default` {
            schema["default"] = .int(defaultValue)
        }

        return .object(schema)
    }

    /// Build a JSON Schema for an array
    public static func array(
        items: Value,
        description: String? = nil,
        minItems: Int? = nil,
        maxItems: Int? = nil) -> Value
    {
        var schema: [String: Value] = [
            "type": .string("array"),
            "items": items,
        ]

        if let desc = description {
            schema["description"] = .string(desc)
        }

        if let min = minItems {
            schema["minItems"] = .int(min)
        }

        if let max = maxItems {
            schema["maxItems"] = .int(max)
        }

        return .object(schema)
    }
}
