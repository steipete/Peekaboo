import Foundation
import TachikomaCore

/// Extensions to convert UnifiedToolDefinition to agent tool formats
@available(macOS 14.0, *)
extension UnifiedToolDefinition {
    /// Convert parameters to agent tool parameters
    public func toAgentParameters() -> ToolParameters {
        var properties: [String: ToolParameterProperty] = [:]
        var required: [String] = []

        for param in parameters {
            // Skip CLI-only parameters that don't make sense for agents
            if param.cliOptions?.argumentType == .argument {
                continue
            }

            let property = switch param.type {
            case .string:
                ToolParameterProperty(
                    type: .string,
                    description: param.description,
                    enumValues: param.options)
            case .integer:
                ToolParameterProperty(
                    type: .integer,
                    description: param.description)
            case .boolean:
                ToolParameterProperty(
                    type: .boolean,
                    description: param.description)
            case .enumeration:
                ToolParameterProperty(
                    type: .string,
                    description: param.description,
                    enumValues: param.options ?? [])
            case .object:
                ToolParameterProperty(
                    type: .object,
                    description: param.description)
            case .array:
                ToolParameterProperty(
                    type: .array,
                    description: param.description)
            }

            // Map CLI parameter names to agent parameter names
            let agentParamName = param.name.replacingOccurrences(of: "-", with: "_")
            properties[agentParamName] = property

            if param.required {
                required.append(agentParamName)
            }
        }

        return ToolParameters(properties: properties, required: required)
    }

    /// Get formatted examples for agent tools
    public var agentExamples: String {
        if examples.isEmpty {
            return ""
        }

        return "\n\nExamples:\n" + examples.map { "  \($0)" }.joined(separator: "\n")
    }
}

/// Map CLI parameter names to their ArgumentParser property wrapper info
public struct ParameterMapping: Sendable {
    public let cliName: String
    public let propertyName: String
    public let argumentType: CLIOptions.ArgumentType

    public init(cliName: String, propertyName: String, argumentType: CLIOptions.ArgumentType) {
        self.cliName = cliName
        self.propertyName = propertyName
        self.argumentType = argumentType
    }
}
