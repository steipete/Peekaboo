import Foundation
import MCP
import os.log

/// MCP tool for clicking UI elements
public struct ClickTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "ClickTool")
    
    public let name = "click"
    
    public var description: String {
        """
        Clicks on UI elements or coordinates.
        Supports element queries, specific IDs from see command, or raw coordinates.
        Includes smart waiting for elements to become actionable.
        Peekaboo MCP 3.0.0-beta.2 using anthropic/claude-opus-4-20250514, ollama/llava:latest
        """
    }
    
    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "query": SchemaBuilder.string(
                    description: "Optional. Element text or query to click. Will search for matching elements."
                ),
                "on": SchemaBuilder.string(
                    description: "Optional. Element ID to click (e.g., B1, T2) from see command output."
                ),
                "coords": SchemaBuilder.string(
                    description: "Optional. Click at specific coordinates in format 'x,y' (e.g., '100,200')."
                ),
                "session": SchemaBuilder.string(
                    description: "Optional. Session ID from see command. Uses latest session if not specified."
                ),
                "wait_for": SchemaBuilder.number(
                    description: "Optional. Maximum milliseconds to wait for element to become actionable. Default: 5000.",
                    default: 5000
                ),
                "double": SchemaBuilder.boolean(
                    description: "Optional. Double-click instead of single click.",
                    default: false
                ),
                "right": SchemaBuilder.boolean(
                    description: "Optional. Right-click (secondary click) instead of left-click.",
                    default: false
                )
            ],
            required: []
        )
    }
    
    public init() {}
    
    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        // Validate that at least one target is specified
        let query = arguments.getString("query")
        let elementId = arguments.getString("on")
        let coords = arguments.getString("coords")
        
        guard query != nil || elementId != nil || coords != nil else {
            return ToolResponse.error("Must specify either 'query', 'on', or 'coords'")
        }
        
        let sessionId = arguments.getString("session")
        let waitFor = arguments.getNumber("wait_for") ?? 5000
        let isDouble = arguments.getBool("double") ?? false
        let isRight = arguments.getBool("right") ?? false
        
        do {
            let startTime = Date()
            
            // Determine click location
            let clickLocation: CGPoint
            let clickedElement: String?
            
            if let coords = coords {
                // Parse coordinates
                let parts = coords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2,
                      let x = Double(parts[0]),
                      let y = Double(parts[1]) else {
                    return ToolResponse.error("Invalid coordinates format. Use 'x,y' (e.g., '100,200')")
                }
                clickLocation = CGPoint(x: x, y: y)
                clickedElement = nil
                
            } else if let elementId = elementId {
                // Find element by ID from session
                guard let session = await getSession(id: sessionId) else {
                    return ToolResponse.error("No active session. Run 'see' command first to capture UI state.")
                }
                
                guard let element = await session.getElement(byId: elementId) else {
                    return ToolResponse.error("Element '\(elementId)' not found in current session. Run 'see' command to update UI state.")
                }
                
                // Calculate center of element
                clickLocation = CGPoint(
                    x: element.frame.midX,
                    y: element.frame.midY
                )
                clickedElement = "\(element.role): \(element.title ?? element.label ?? "untitled")"
                
            } else if let query = query {
                // Search for element by text
                guard let session = await getSession(id: sessionId) else {
                    return ToolResponse.error("No active session. Run 'see' command first to capture UI state.")
                }
                
                // Find matching element
                let elements = await session.uiElements
                let matches = elements.filter { element in
                    let searchText = query.lowercased()
                    return element.title?.lowercased().contains(searchText) ?? false ||
                           element.label?.lowercased().contains(searchText) ?? false ||
                           element.value?.lowercased().contains(searchText) ?? false
                }
                
                guard !matches.isEmpty else {
                    return ToolResponse.error("No elements found matching query: '\(query)'")
                }
                
                // Use first actionable match, or first match if none are actionable
                let element = matches.first { $0.isActionable } ?? matches.first!
                
                clickLocation = CGPoint(
                    x: element.frame.midX,
                    y: element.frame.midY
                )
                clickedElement = "\(element.role): \(element.title ?? element.label ?? "untitled")"
                
            } else {
                return ToolResponse.error("No click target specified")
            }
            
            // Perform the click
            let clickService = PeekabooServices.shared.automation
            
            if isDouble {
                try await clickService.click(
                    target: .coordinates(clickLocation),
                    clickType: .double,
                    sessionId: sessionId
                )
            } else if isRight {
                try await clickService.click(
                    target: .coordinates(clickLocation),
                    clickType: .right,
                    sessionId: sessionId
                )
            } else {
                try await clickService.click(
                    target: .coordinates(clickLocation),
                    clickType: .single,
                    sessionId: sessionId
                )
            }
            
            let executionTime = Date().timeIntervalSince(startTime)
            
            // Build response
            var message = "✅ "
            if isDouble {
                message += "Double-clicked"
            } else if isRight {
                message += "Right-clicked"
            } else {
                message += "Clicked"
            }
            
            if let element = clickedElement {
                message += " on \(element)"
            }
            message += " at (\(Int(clickLocation.x)), \(Int(clickLocation.y)))"
            message += " in \(String(format: "%.2f", executionTime))s"
            
            // Break up complex expression for type checker
            let clickLocationMeta = Value.object([
                "x": .double(Double(clickLocation.x)),
                "y": .double(Double(clickLocation.y))
            ])
            
            let clickedElementMeta: Value = clickedElement != nil ? .string(clickedElement!) : .null
            
            let metaDict: [String: Value] = [
                "click_location": clickLocationMeta,
                "execution_time": .double(executionTime),
                "clicked_element": clickedElementMeta
            ]
            
            return ToolResponse(
                content: [.text(message)],
                meta: .object(metaDict)
            )
            
        } catch {
            logger.error("Click execution failed: \(error)")
            return ToolResponse.error("Failed to perform click: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helpers
    
    private func getSession(id: String?) async -> UISession? {
        if let sessionId = id {
            return await UISessionManager.shared.getSession(id: sessionId)
        }
        
        // Get most recent session
        // For now, return nil - in a real implementation we'd track the most recent session
        return nil
    }
}