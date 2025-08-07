//
//  TypedValueBridge.swift
//  PeekabooCore
//

import Foundation
import MCP
import Tachikoma

// MARK: - Bridge between TypedValue and external types

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
public extension TypedValue {
    
    // MARK: - MCP Value Conversion
    
    /// Convert from MCP Value to TypedValue
    static func from(_ value: Value) -> TypedValue {
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
            return .array(values.map { TypedValue.from($0) })
        case .object(let dict):
            return .object(dict.mapValues { TypedValue.from($0) })
        case .data(let mimeType, let data):
            // Convert data to a special object representation
            return .object([
                "type": .string("data"),
                "mimeType": .string(mimeType ?? "application/octet-stream"),
                "dataSize": .int(data.count)
            ])
        }
    }
    
    /// Convert TypedValue to MCP Value
    func toMCPValue() -> Value {
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
    
    /// Convert from AnyAgentToolValue to TypedValue
    static func from(_ value: AnyAgentToolValue) throws -> TypedValue {
        let json = try value.toJSON()
        return try TypedValue.fromJSON(json)
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
extension Value {
    /// Convert MCP Value to AnyAgentToolValue via TypedValue
    func toAnyAgentToolValue() -> AnyAgentToolValue {
        return TypedValue.from(self).toAnyAgentToolValue()
    }
    
    /// Create MCP Value from Any type via TypedValue
    static func from(_ any: Any) -> Value {
        do {
            let typedValue = try TypedValue.fromJSON(any)
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
    static func from(_ value: Value) -> AnyAgentToolValue {
        return TypedValue.from(value).toAnyAgentToolValue()
    }
    
    /// Create from Any type via TypedValue
    static func from(_ any: Any) -> AnyAgentToolValue {
        do {
            let typedValue = try TypedValue.fromJSON(any)
            return typedValue.toAnyAgentToolValue()
        } catch {
            // Fallback to string representation
            return AnyAgentToolValue(string: String(describing: any))
        }
    }
    
    /// Convert to MCP Value via TypedValue
    func toValue() -> Value {
        do {
            let typedValue = try TypedValue.from(self)
            return typedValue.toMCPValue()
        } catch {
            // Fallback
            if let str = self.stringValue {
                return .string(str)
            } else if let num = self.intValue {
                return .int(num)
            } else if let num = self.doubleValue {
                return .double(num)
            } else if let bool = self.boolValue {
                return .bool(bool)
            } else if self.isNull {
                return .null
            } else {
                return .null
            }
        }
    }
}