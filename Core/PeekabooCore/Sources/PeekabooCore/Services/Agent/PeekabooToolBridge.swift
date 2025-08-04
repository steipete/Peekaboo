import Foundation
import Tachikoma

// MARK: - PeekabooToolBridge

/// Bridge that converts Peekaboo's native Tool<PeekabooServices> to TachikomaCore's SimpleTool format
/// This eliminates the need for duplicate SimpleTool implementations while preserving rich tool validation
@available(macOS 14.0, *)
public class PeekabooToolBridge: @unchecked Sendable {
    private let services: PeekabooServices
    private let nativeTools: [Tool<PeekabooServices>]
    
    public init(services: PeekabooServices, nativeTools: [Tool<PeekabooServices>]) {
        self.services = services
        self.nativeTools = nativeTools
    }
    
    /// Convert Peekaboo's native tools to TachikomaCore SimpleTool format
    public func createSimpleTools() -> [SimpleTool] {
        return nativeTools.compactMap { nativeTool in
            do {
                return try convertToSimpleTool(nativeTool)
            } catch {
                // Log conversion error but don't fail the entire bridge
                print("Warning: Failed to convert tool '\(nativeTool.name)' to SimpleTool: \(error)")
                return nil
            }
        }
    }
    
    /// Convert a single native tool to SimpleTool format
    private func convertToSimpleTool(_ nativeTool: Tool<PeekabooServices>) throws -> SimpleTool {
        // Convert Peekaboo's ToolParameters to TachikomaCore's ToolParameters
        let convertedParameters = convertParameters(nativeTool.parameters)
        
        return SimpleTool(
            name: nativeTool.name,
            description: nativeTool.description,
            parameters: convertedParameters,
            execute: { [self] (tachikomaArgs: Tachikoma.ToolArguments) in
                
                // Convert TachikomaCore arguments to Peekaboo format
                let peekabooInput = try self.convertArgumentsToPeekabooInput(tachikomaArgs)
                
                // Execute the native Peekaboo tool
                let peekabooOutput = try await nativeTool.execute(peekabooInput, self.services)
                
                // Convert Peekaboo output to TachikomaCore format
                return self.convertPeekabooOutputToTachikomaArgument(peekabooOutput)
            }
        )
    }
    
    // MARK: - Parameter Conversion
    
    /// Convert Peekaboo ToolParameters to TachikomaCore ToolParameters
    private func convertParameters(_ peekabooParams: ToolParameters) -> ToolParameters {
        var convertedProperties: [String: ToolParameterProperty] = [:]
        
        // Convert each parameter property
        for (key, property) in peekabooParams.properties {
            convertedProperties[key] = convertParameterProperty(property)
        }
        
        return ToolParameters(
            properties: convertedProperties,
            required: peekabooParams.required
        )
    }
    
    /// Convert individual parameter property  
    private func convertParameterProperty(_ property: ToolParameterProperty) -> ToolParameterProperty {
        // Map Peekaboo parameter types to TachikomaCore types
        let convertedType: ToolParameterProperty.ParameterType
        switch property.type {
        case .string:
            convertedType = .string
        case .integer:
            convertedType = .integer
        case .boolean:
            convertedType = .boolean
        case .array:
            convertedType = .array
        case .object:
            convertedType = .object
        case .number:
            convertedType = .number
        case .null:
            convertedType = .null
        }
        
        // Get enum values directly from TachikomaCore property
        let enumValues = property.enumValues
        
        return ToolParameterProperty(
            type: convertedType,
            description: property.description,
            enumValues: enumValues,
            minimum: property.minimum,
            maximum: property.maximum,
            minLength: property.minLength,
            maxLength: property.maxLength
        )
    }
    
    // MARK: - Argument Conversion
    
    /// Convert TachikomaCore ToolArguments to Peekaboo ToolInput
    private func convertArgumentsToPeekabooInput(_ tachikomaArgs: Tachikoma.ToolArguments) throws -> ToolInput {
        // Both ToolArguments and ToolInput use the same [String: ToolArgument] structure
        // We can directly pass the arguments from TachikomaCore to Peekaboo
        return ToolInput(tachikomaArgs.allArguments)
    }
    
    /// Convert Peekaboo ToolOutput to TachikomaCore ToolArgument
    private func convertPeekabooOutputToTachikomaArgument(_ peekabooOutput: ToolOutput) -> ToolArgument {
        switch peekabooOutput {
        case .string(let str):
            return .string(str)
        case .int(let int):
            return .int(int)
        case .double(let double):
            return .double(double)
        case .bool(let bool):
            return .bool(bool)
        case .array(let array):
            let convertedArray = array.map { convertPeekabooOutputToTachikomaArgument($0) }
            return .array(convertedArray)
        case .object(let dict):
            let convertedDict = dict.mapValues { convertPeekabooOutputToTachikomaArgument($0) }
            return .object(convertedDict)
        case .null:
            return .null
        }
    }
}

// MARK: - Extensions

extension PeekabooAgentService {
    /// Create TachikomaCore-compatible tools using the bridge
    func createBridgedSimpleTools() -> [SimpleTool] {
        let nativeTools = createPeekabooTools()
        let bridge = PeekabooToolBridge(services: services, nativeTools: nativeTools)
        // Note: The bridge is stored in the returned SimpleTool closures, keeping it alive
        return bridge.createSimpleTools()
    }
}