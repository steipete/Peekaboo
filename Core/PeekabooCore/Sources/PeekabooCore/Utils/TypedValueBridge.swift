import Foundation
import MCP
import Tachikoma

enum TypedValueBridge {
    static func typedValue(from value: MCP.Value) -> Tachikoma.TypedValue {
        switch value {
        case .null:
            return .null
        case let .bool(v):
            return .bool(v)
        case let .int(v):
            return .int(v)
        case let .double(v):
            return .double(v)
        case let .string(v):
            return .string(v)
        case let .array(values):
            return .array(values.map { typedValue(from: $0) })
        case let .object(dict):
            return .object(dict.mapValues { typedValue(from: $0) })
        default:
            return .null
        }
    }

    static func mcpValue(from typedValue: Tachikoma.TypedValue) -> MCP.Value {
        switch typedValue {
        case .null:
            return .null
        case let .bool(v):
            return .bool(v)
        case let .int(v):
            return .int(v)
        case let .double(v):
            return .double(v)
        case let .string(v):
            return .string(v)
        case let .array(values):
            return .array(values.map { mcpValue(from: $0) })
        case let .object(dict):
            return .object(dict.mapValues { mcpValue(from: $0) })
        }
    }

    static func typedValue(from anyAgentValue: AnyAgentToolValue) throws -> Tachikoma.TypedValue {
        let json = try anyAgentValue.toJSON()
        return try Tachikoma.TypedValue.fromJSON(json)
    }

    static func anyAgentValue(from typedValue: Tachikoma.TypedValue) -> AnyAgentToolValue {
        switch typedValue {
        case .null:
            return AnyAgentToolValue(null: ())
        case let .bool(v):
            return AnyAgentToolValue(bool: v)
        case let .int(v):
            return AnyAgentToolValue(int: v)
        case let .double(v):
            return AnyAgentToolValue(double: v)
        case let .string(v):
            return AnyAgentToolValue(string: v)
        case let .array(values):
            return AnyAgentToolValue(array: values.map { anyAgentValue(from: $0) })
        case let .object(dict):
            return AnyAgentToolValue(object: dict.mapValues { anyAgentValue(from: $0) })
        }
    }

    static func anyAgentValue(from value: MCP.Value) -> AnyAgentToolValue {
        anyAgentValue(from: typedValue(from: value))
    }

    static func anyAgentValue(fromAny any: Any) -> AnyAgentToolValue {
        do {
            let typedValue = try Tachikoma.TypedValue.fromJSON(any)
            return anyAgentValue(from: typedValue)
        } catch {
            return AnyAgentToolValue(string: String(describing: any))
        }
    }

    static func mcpValue(from anyAgentValue: AnyAgentToolValue) -> MCP.Value {
        let typedValue = (try? typedValue(from: anyAgentValue)) ?? .null
        return mcpValue(from: typedValue)
    }

    static func any(from anyAgentValue: AnyAgentToolValue) -> Any {
        do {
            return try anyAgentValue.toJSON()
        } catch {
            return String(describing: anyAgentValue)
        }
    }
}
