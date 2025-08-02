import Foundation
import Tachikoma

/// Extensions to convert UnifiedToolDefinition to agent tool formats
@available(macOS 14.0, *)
extension UnifiedToolDefinition {
    /// Convert parameters to agent tool parameters
    public func toAgentParameters() -> ToolParameters {
        var properties: [String: ParameterSchema] = [:]
        var required: [String] = []
        
        for param in parameters {
            // Skip CLI-only parameters that don't make sense for agents
            if param.cliOptions?.argumentType == .argument {
                continue
            }
            
            let schema: ParameterSchema
            switch param.type {
            case .string:
                if let options = param.options {
                    schema = .enumeration(options, description: param.description)
                } else {
                    schema = .string(description: param.description)
                }
            case .integer:
                schema = .integer(description: param.description)
            case .boolean:
                schema = .boolean(description: param.description)
            case .enumeration:
                schema = .enumeration(param.options ?? [], description: param.description)
            case .object:
                schema = .object(properties: [:], description: param.description)
            case .array:
                schema = .array(of: .string(description: ""), description: param.description)
            }
            
            // Map CLI parameter names to agent parameter names
            let agentParamName = param.name.replacingOccurrences(of: "-", with: "_")
            properties[agentParamName] = schema
            
            if param.required {
                required.append(agentParamName)
            }
        }
        
        return ToolParameters.object(properties: properties, required: required)
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