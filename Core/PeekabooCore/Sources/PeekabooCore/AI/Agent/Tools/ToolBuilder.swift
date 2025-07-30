import Foundation
import CoreGraphics

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
        var result: [String: ToolOutput] = ["result": .string(output)]
        for (key, value) in metadata {
            result[key] = .string(value)
        }
        return .object(result)
    }
    
    /// Create a success result with metadata dictionary
    public static func success(
        _ output: String,
        metadata: [String: String] = [:]
    ) -> ToolOutput {
        var result: [String: ToolOutput] = ["result": .string(output)]
        for (key, value) in metadata {
            result[key] = .string(value)
        }
        return .object(result)
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
        handler: @escaping (ToolParameterParser, PeekabooServices) async throws -> ToolOutput
    ) -> Tool<PeekabooServices> {
        Tool(
            name: name,
            description: description,
            parameters: parameters,
            execute: { params, context in
                // Ensure all tool handlers run on the main thread to prevent AX API crashes
                do {
                    let toolParams = try ToolParameterParser(params, toolName: name)
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
                // Ensure all tool handlers run on the main thread to prevent AX API crashes
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
        operation: (ServiceWindowInfo) async throws -> ToolOutput
    ) async throws -> ToolOutput {
        // Get all windows from all applications
        let apps = try await context.applications.listApplications()
        var windows: [ServiceWindowInfo] = []
        for app in apps {
            let appWindows = try await context.windows.listWindows(target: .application(app.name))
            windows.append(contentsOf: appWindows)
        }
        
        let targetWindow: ServiceWindowInfo
        if let appName = appName {
            // We need to match windows by the app name
            // Since ServiceWindowInfo doesn't have applicationName, we need to filter differently
            let matchingWindows = try await context.windows.listWindows(target: .application(appName))
            guard let window = matchingWindows.first else {
                throw PeekabooError.windowNotFound(criteria: "application '\(appName)'")
            }
            targetWindow = window
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
        operation: (ServiceApplicationInfo) async throws -> ToolOutput
    ) async throws -> ToolOutput {
        let apps = try await context.applications.listApplications()
        
        guard let app = apps.first(where: { $0.name.lowercased() == appName.lowercased() }) else {
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