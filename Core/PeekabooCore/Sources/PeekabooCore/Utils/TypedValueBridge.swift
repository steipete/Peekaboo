//
//  TypedValueBridge.swift
//  PeekabooCore
//

import Foundation
import MCP
import Tachikoma

// MARK: - Bridge between TypedValue and external types

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
public extension Tachikoma.TypedValue {
    
    // MARK: - MCP Value Conversion
    
    /// Convert from MCP Value to TypedValue
    static func fromMCPValue(_ value: MCP.Value) -> Tachikoma.TypedValue {
        switch value {
        case .null:
            return .null
        case .bool(let v):
            return .bool(v)
        case .int(let v):
            return .int(v)
        case .double(let v):
            return .double(v)
        case .string(let v):
            return .string(v)
        case .array(let values):
            return .array(values.map { Tachikoma.TypedValue.fromMCPValue($0) })
        case .object(let dict):
            return .object(dict.mapValues { Tachikoma.TypedValue.fromMCPValue($0) })
        default:
            // For unsupported types, convert to null
            return .null
        }
    }
    
    /// Convert TypedValue to MCP Value
    func toMCPValue() -> MCP.Value {
        switch self {
        case .null:
            return .null
        case .bool(let v):
            return .bool(v)
        case .int(let v):
            return .int(v)
        case .double(let v):
            return .double(v)
        case .string(let v):
            return .string(v)
        case .array(let values):
            return .array(values.map { $0.toMCPValue() })
        case .object(let dict):
            return .object(dict.mapValues { $0.toMCPValue() })
        }
    }
    
    // MARK: - AnyAgentToolValue Conversion
    
    /// Convert from AnyAgentToolValue to TypedValue via JSON
    static func fromAnyAgentToolValueViaJSON(_ value: AnyAgentToolValue) throws -> Tachikoma.TypedValue {
        let json = try value.toJSON()
        return try Tachikoma.TypedValue.fromJSON(json)
    }
    
    /// Convert TypedValue to AnyAgentToolValue
    func toAnyAgentToolValue() -> AnyAgentToolValue {
        switch self {
        case .null:
            return AnyAgentToolValue(null: ())
        case .bool(let v):
            return AnyAgentToolValue(bool: v)
        case .int(let v):
            return AnyAgentToolValue(int: v)
        case .double(let v):
            return AnyAgentToolValue(double: v)
        case .string(let v):
            return AnyAgentToolValue(string: v)
        case .array(let values):
            return AnyAgentToolValue(array: values.map { $0.toAnyAgentToolValue() })
        case .object(let dict):
            return AnyAgentToolValue(object: dict.mapValues { $0.toAnyAgentToolValue() })
        }
    }
}

// MARK: - MCP Value Extension

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
extension MCP.Value {
    /// Convert MCP Value to AnyAgentToolValue via TypedValue
    func toAnyAgentToolValue() -> AnyAgentToolValue {
        return Tachikoma.TypedValue.fromMCPValue(self).toAnyAgentToolValue()
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
        return Tachikoma.TypedValue.fromMCPValue(value).toAnyAgentToolValue()
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