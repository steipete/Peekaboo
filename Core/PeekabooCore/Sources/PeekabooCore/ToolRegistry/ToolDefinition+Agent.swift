import Foundation
import Tachikoma

/// Extensions to convert PeekabooToolDefinition to agent tool formats
@available(macOS 14.0, *)
extension PeekabooToolDefinition {
    /// Convert parameters to agent tool parameters
    public func toAgentToolParameters() -> Tachikoma.AgentToolParameters {
        var properties: [Tachikoma.AgentToolParameterProperty] = []
        var required: [String] = []

        for param in parameters {
            // Skip CLI-only parameters that don't make sense for agents
            if param.cliOptions?.argumentType == .argument {
                continue
            }

            let parameterType: Tachikoma.AgentToolParameterProperty.ParameterType = switch param.type {
            case .string, .enumeration:
                .string
            case .integer:
                .integer
            case .number:
                .number
            case .boolean:
                .boolean
            case .object:
                .object
            case .array:
                .array
            }

            let agentParamName = param.name.replacingOccurrences(of: "-", with: "_")
            
            let property = Tachikoma.AgentToolParameterProperty(
                name: agentParamName,
                type: parameterType,
                description: param.description,
                enumValues: param.options)
                
            properties.append(property)

            if param.required {
                required.append(agentParamName)
            }
        }

        return Tachikoma.AgentToolParameters(properties: properties, required: required)
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
