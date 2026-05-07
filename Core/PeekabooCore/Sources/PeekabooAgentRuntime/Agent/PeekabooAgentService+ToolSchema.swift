import Foundation
import MCP
import Tachikoma

@available(macOS 14.0, *)
extension PeekabooAgentService {
    // MARK: - MCP Schema Conversion

    func convertMCPSchemaToAgentSchema(_ mcpSchema: Value) -> AgentToolParameters {
        guard case let .object(schemaDict) = mcpSchema,
              let propertiesValue = schemaDict["properties"],
              case let .object(properties) = propertiesValue
        else {
            return AgentToolParameters(properties: [:], required: [])
        }

        var agentProperties: [String: AgentToolParameterProperty] = [:]
        for (key, value) in properties {
            guard let property = self.makeAgentToolProperty(name: key, value: value) else { continue }
            agentProperties[key] = property
        }

        return AgentToolParameters(
            properties: agentProperties,
            required: self.requiredFields(from: schemaDict))
    }

    private func requiredFields(from schemaDict: [String: Value]) -> [String] {
        guard case let .array(requiredValues) = schemaDict["required"] else { return [] }
        return requiredValues.compactMap { value in
            if case let .string(str) = value { str } else { nil }
        }
    }

    private func makeAgentToolProperty(name: String, value: Value) -> AgentToolParameterProperty? {
        guard case let .object(propDict) = value,
              let typeValue = propDict["type"],
              case let .string(typeStr) = typeValue
        else {
            return nil
        }

        let paramType = AgentToolParameterProperty.ParameterType(rawValue: typeStr) ?? .string
        let description = self.descriptionValue(from: propDict["description"])
        let enumValues = self.enumValues(from: propDict["enum"])
        let items = self.itemsDefinition(for: paramType, itemsValue: propDict["items"])

        return AgentToolParameterProperty(
            name: name,
            type: paramType,
            description: description,
            enumValues: enumValues,
            items: items)
    }

    private func descriptionValue(from value: Value?) -> String {
        guard case let .string(description) = value else { return "" }
        return description
    }

    private func enumValues(from value: Value?) -> [String]? {
        guard case let .array(enumArray) = value else { return nil }
        let values = enumArray.compactMap { element -> String? in
            if case let .string(str) = element { str } else { nil }
        }
        return values.isEmpty ? nil : values
    }

    private func itemsDefinition(
        for parameterType: AgentToolParameterProperty.ParameterType,
        itemsValue: Value?) -> AgentToolParameterItems?
    {
        guard parameterType == .array else { return nil }

        guard case let .object(itemsDict) = itemsValue else {
            return AgentToolParameterItems(type: AgentToolParameterProperty.ParameterType.string.rawValue)
        }

        let itemType: AgentToolParameterProperty.ParameterType = if case let .string(typeString) = itemsDict["type"],
                                                                    let resolved = AgentToolParameterProperty
                                                                        .ParameterType(rawValue: typeString)
        {
            resolved
        } else {
            .string
        }

        return AgentToolParameterItems(
            type: itemType.rawValue,
            description: self.descriptionValue(from: itemsDict["description"]))
    }
}
