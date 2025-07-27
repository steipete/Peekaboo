import Foundation
import AXorcist

// MARK: - Temporary Type Definitions
// TODO: These should be properly defined in their respective modules

/// Criteria for searching UI elements
public enum UIElementSearchCriteria {
    case label(String)
    case identifier(String)
    case type(String)
}

// MARK: - Tool Result Builders

extension ToolOutput {
    /// Create a success result with convenient syntax
    public static func success(
        _ output: String,
        metadata: (String, String)...
    ) -> ToolOutput {
        var result: [String: Any] = ["result": output]
        for (key, value) in metadata {
            result[key] = value
        }
        return .dictionary(result)
    }
    
    /// Create a success result with metadata dictionary
    public static func success(
        _ output: String,
        metadata: [String: String] = [:]
    ) -> ToolOutput {
        var result: [String: Any] = ["result": output]
        for (key, value) in metadata {
            result[key] = value
        }
        return .dictionary(result)
    }
}

// MARK: - Tool Parameter Helpers

/// Helper for extracting and validating tool parameters
@available(macOS 14.0, *)
public struct ToolParameterExtractor {
    private let params: [String: AnyCodable]
    private let toolName: String
    
    init(_ params: [String: AnyCodable], toolName: String) {
        self.params = params
        self.toolName = toolName
    }
    
    /// Get a required string parameter
    public func string(_ key: String) throws -> String {
        guard let codable = params[key],
              let value = codable.value as? String else {
            throw PeekabooError.invalidInput("\(toolName): '\(key)' parameter is required")
        }
        return value
    }
    
    /// Get an optional string parameter
    public func string(_ key: String, default defaultValue: String? = nil) -> String? {
        guard let codable = params[key] else { return defaultValue }
        return codable.value as? String ?? defaultValue
    }
    
    /// Get a required integer parameter
    public func int(_ key: String) throws -> Int {
        guard let codable = params[key],
              let value = codable.value as? Int else {
            throw PeekabooError.invalidInput("\(toolName): '\(key)' parameter is required")
        }
        return value
    }
    
    /// Get an optional integer parameter
    public func int(_ key: String, default defaultValue: Int? = nil) -> Int? {
        guard let codable = params[key] else { return defaultValue }
        return codable.value as? Int ?? defaultValue
    }
    
    /// Get an optional boolean parameter
    public func bool(_ key: String, default defaultValue: Bool = false) -> Bool {
        guard let codable = params[key] else { return defaultValue }
        return codable.value as? Bool ?? defaultValue
    }
    
    /// Get an optional array of strings
    public func stringArray(_ key: String) -> [String]? {
        guard let codable = params[key],
              let array = codable.value as? [Any] else { return nil }
        return array.compactMap { $0 as? String }
    }
    
    /// Parse coordinates from "x,y" format
    public func coordinates(_ key: String) throws -> CGPoint? {
        guard let codable = params[key],
              let coordString = codable.value as? String else { return nil }
        
        guard coordString.contains(","),
              let commaIndex = coordString.firstIndex(of: ",") else {
            return nil
        }
        
        let xStr = String(coordString[..<commaIndex]).trimmingCharacters(in: .whitespaces)
        let yStr = String(coordString[coordString.index(after: commaIndex)...])
            .trimmingCharacters(in: .whitespaces)
        
        guard let x = Double(xStr), let y = Double(yStr) else {
            throw PeekabooError.invalidInput("\(toolName): Invalid coordinates format. Use 'x,y'")
        }
        
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Tool Creation Helpers

@available(macOS 14.0, *)
extension PeekabooAgentService {
    /// Create a tool with simplified parameter handling
    func createTool(
        name: String,
        description: String,
        parameters: ToolParameters,
        handler: @escaping (ToolParameterExtractor, PeekabooServices) async throws -> ToolOutput
    ) -> Tool<PeekabooServices> {
        Tool(
            name: name,
            description: description,
            parameters: parameters,
            execute: { params, context in
                let toolParams = ToolParameterExtractor(params, toolName: name)
                do {
                    return try await handler(toolParams, context)
                } catch {
                    return await self.handleToolError(error, for: name, in: context)
                }
            }
        )
    }
    
    /// Create a simple tool with no parameters
    func createSimpleTool(
        name: String,
        description: String,
        handler: @escaping (PeekabooServices) async throws -> ToolOutput
    ) -> Tool<PeekabooServices> {
        Tool(
            name: name,
            description: description,
            parameters: ToolParameters.object(properties: [:], required: []),
            execute: { _, context in
                do {
                    return try await handler(context)
                } catch {
                    return await self.handleToolError(error, for: name, in: context)
                }
            }
        )
    }
}

// MARK: - Common Tool Patterns

@available(macOS 14.0, *)
extension PeekabooAgentService {
    /// Common pattern for window-based operations
    func performWindowOperation(
        appName: String?,
        context: PeekabooServices,
        operation: (WindowInfo) async throws -> ToolOutput
    ) async throws -> ToolOutput {
        let windows = try await context.windowManagement.listWindows()
        
        let targetWindow: WindowInfo
        if let appName = appName {
            targetWindow = try windows.findWindow(byAppName: appName)
        } else {
            // Use frontmost window
            guard let window = windows.first else {
                throw PeekabooError.windowNotFound(criteria: "any window")
            }
            targetWindow = window
        }
        
        return try await operation(targetWindow)
    }
    
    /// Common pattern for app-based operations
    func performAppOperation(
        appName: String,
        context: PeekabooServices,
        operation: (ApplicationInfo) async throws -> ToolOutput
    ) async throws -> ToolOutput {
        let apps = try await context.application.listApplications()
        
        guard let app = apps.findApp(byName: appName) else {
            throw PeekabooError.appNotFound(appName)
        }
        
        return try await operation(app)
    }
    
    // TODO: This function needs to be updated once UIAutomationServiceProtocol supports findElement
    /*
    /// Common pattern for element finding with retry
    func findElementWithRetry(
        criteria: UIElementSearchCriteria,
        in appName: String?,
        context: PeekabooServices,
        maxAttempts: Int = 3
    ) async throws -> Element {
        for attempt in 1...maxAttempts {
            do {
                return try await context.uiAutomation.findElement(
                    matching: criteria,
                    in: appName
                )
            } catch {
                if attempt < maxAttempts {
                    // Wait before retry
                    try await Task.sleep(nanoseconds: TimeInterval.shortDelay.nanoseconds)
                } else {
                    throw error
                }
            }
        }
        
        throw PeekabooError.elementNotFound(type: "element", in: appName ?? "screen")
    }
    */
}