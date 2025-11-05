//
//  TypedValueBridge.swift
//  PeekabooCore
//

import Foundation
import MCP
import Tachikoma

// MARK: - Bridge between TypedValue and external types

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
extension Tachikoma.TypedValue {
    // MARK: - MCP Value Conversion

    /// Convert from MCP Value to TypedValue
    public static func fromMCPValue(_ value: MCP.Value) -> Tachikoma.TypedValue {
        switch value {
        case .null:
            .null
        case let .bool(v):
            .bool(v)
        case let .int(v):
            .int(v)
        case let .double(v):
            .double(v)
        case let .string(v):
            .string(v)
        case let .array(values):
            .array(values.map { Tachikoma.TypedValue.fromMCPValue($0) })
        case let .object(dict):
            .object(dict.mapValues { Tachikoma.TypedValue.fromMCPValue($0) })
        default:
            // For unsupported types, convert to null
            .null
        }
    }

    /// Convert TypedValue to MCP Value
    public func toMCPValue() -> MCP.Value {
        switch self {
        case .null:
            .null
        case let .bool(v):
            .bool(v)
        case let .int(v):
            .int(v)
        case let .double(v):
            .double(v)
        case let .string(v):
            .string(v)
        case let .array(values):
            .array(values.map { $0.toMCPValue() })
        case let .object(dict):
            .object(dict.mapValues { $0.toMCPValue() })
        }
    }

    // MARK: - AnyAgentToolValue Conversion

    /// Convert from AnyAgentToolValue to TypedValue via JSON
    public static func fromAnyAgentToolValueViaJSON(_ value: AnyAgentToolValue) throws -> Tachikoma.TypedValue {
        let json = try value.toJSON()
        return try Tachikoma.TypedValue.fromJSON(json)
    }

    /// Convert TypedValue to AnyAgentToolValue
    public func toAnyAgentToolValue() -> AnyAgentToolValue {
        switch self {
        case .null:
            AnyAgentToolValue(null: ())
        case let .bool(v):
            AnyAgentToolValue(bool: v)
        case let .int(v):
            AnyAgentToolValue(int: v)
        case let .double(v):
            AnyAgentToolValue(double: v)
        case let .string(v):
            AnyAgentToolValue(string: v)
        case let .array(values):
            AnyAgentToolValue(array: values.map { $0.toAnyAgentToolValue() })
        case let .object(dict):
            AnyAgentToolValue(object: dict.mapValues { $0.toAnyAgentToolValue() })
        }
    }
}

// MARK: - MCP Value Extension

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
extension MCP.Value {
    /// Convert MCP Value to AnyAgentToolValue via TypedValue
    func toAnyAgentToolValue() -> AnyAgentToolValue {
        Tachikoma.TypedValue.fromMCPValue(self).toAnyAgentToolValue()
    }

    /// Create MCP Value from Any type via TypedValue
    static func fromAny(_ any: Any) -> MCP.Value {
        do {
            let typedValue = try Tachikoma.TypedValue.fromJSON(any)
            return typedValue.toMCPValue()
        } catch {
            // Fallback to string representation
            return .string(String(describing: any))
        }
    }
}

// MARK: - AnyAgentToolValue Extension

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
extension AnyAgentToolValue {
    /// Convert to Any type for interop
    func toAny() -> Any {
        do {
            return try self.toJSON()
        } catch {
            // Fallback to string representation if conversion fails
            return String(describing: self)
        }
    }

    /// Create from MCP Value via TypedValue
    static func fromMCPValue(_ value: MCP.Value) -> AnyAgentToolValue {
        Tachikoma.TypedValue.fromMCPValue(value).toAnyAgentToolValue()
    }

    /// Create from Any type via TypedValue
    static func fromAny(_ any: Any) -> AnyAgentToolValue {
        do {
            let typedValue = try Tachikoma.TypedValue.fromJSON(any)
            return typedValue.toAnyAgentToolValue()
        } catch {
            // Fallback to string representation
            return AnyAgentToolValue(string: String(describing: any))
        }
    }

    /// Convert to MCP Value via TypedValue
    func toValue() -> MCP.Value {
        let typedValue = Tachikoma.TypedValue.from(self as AnyAgentToolValue)
        return typedValue.toMCPValue()
    }
}
