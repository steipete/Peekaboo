import Foundation
import MCP
import os.log

/// MCP tool for typing text
public struct TypeTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "TypeTool")
    
    public let name = "type"
    
    public var description: String {
        """
        Types text into UI elements or at current focus.
        Supports special keys ({return}, {tab}, etc.) and configurable typing speed.
        Can target specific elements or type at current keyboard focus.
        Peekaboo MCP 3.0.0-beta.2 using anthropic/claude-opus-4-20250514, ollama/llava:latest
        """
    }
    
    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "text": SchemaBuilder.string(
                    description: "The text to type. If not specified, can use special key flags instead."
                ),
                "on": SchemaBuilder.string(
                    description: "Optional. Element ID to type into (from see command). If not specified, types at current focus."
                ),
                "session": SchemaBuilder.string(
                    description: "Optional. Session ID from see command. Uses latest session if not specified."
                ),
                "delay": SchemaBuilder.number(
                    description: "Optional. Delay between keystrokes in milliseconds. Default: 5.",
                    default: 5
                ),
                "clear": SchemaBuilder.boolean(
                    description: "Optional. Clear the field before typing (Cmd+A, Delete).",
                    default: false
                ),
                "press_return": SchemaBuilder.boolean(
                    description: "Optional. Press return/enter after typing.",
                    default: false
                ),
                "tab": SchemaBuilder.number(
                    description: "Optional. Press tab N times."
                ),
                "escape": SchemaBuilder.boolean(
                    description: "Optional. Press escape key.",
                    default: false
                ),
                "delete": SchemaBuilder.boolean(
                    description: "Optional. Press delete/backspace key.",
                    default: false
                )
            ],
            required: []
        )
    }
    
    public init() {}
    
    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        let text = arguments.getString("text")
        let elementId = arguments.getString("on")
        let sessionId = arguments.getString("session")
        let delay = Int(arguments.getNumber("delay") ?? 5)
        let clear = arguments.getBool("clear") ?? false
        let pressReturn = arguments.getBool("press_return") ?? false
        let tabCount = arguments.getNumber("tab").map { Int($0) }
        let escape = arguments.getBool("escape") ?? false
        let delete = arguments.getBool("delete") ?? false
        
        // Validate that something will be typed
        guard text != nil || tabCount != nil || escape || delete || pressReturn else {
            return ToolResponse.error("Must specify text to type or special key actions")
        }
        
        do {
            let startTime = Date()
            let automation = PeekabooServices.shared.automation
            
            // Focus on element if specified
            if let elementId = elementId {
                guard let session = await getSession(id: sessionId) else {
                    return ToolResponse.error("No active session. Run 'see' command first to capture UI state.")
                }
                
                guard let element = await session.getElement(byId: elementId) else {
                    return ToolResponse.error("Element '\(elementId)' not found in current session. Run 'see' command to update UI state.")
                }
                
                // Click on the element to focus it
                let clickLocation = CGPoint(
                    x: element.frame.midX,
                    y: element.frame.midY
                )
                // Use proper click API with target and sessionId
                try await automation.click(
                    target: .coordinates(clickLocation),
                    clickType: .single,
                    sessionId: sessionId
                )
                
                // Small delay after clicking
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            
            // Clear field if requested
            if clear {
                // Select all (Cmd+A)
                try await automation.hotkey(keys: "cmd,a", holdDuration: 50)
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                
                // Delete
                try await automation.hotkey(keys: "delete", holdDuration: 50)
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            }
            
            // Type the text
            if let text = text {
                try await automation.type(text: text, target: nil, clearExisting: false, typingDelay: Int(delay), sessionId: sessionId)
            }
            
            // Press tab if requested
            if let tabCount = tabCount {
                for _ in 0..<tabCount {
                    try await automation.hotkey(keys: "tab", holdDuration: 50)
                    if tabCount > 1 {
                        try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000)
                    }
                }
            }
            
            // Press escape if requested
            if escape {
                try await automation.hotkey(keys: "escape", holdDuration: 50)
            }
            
            // Press delete if requested
            if delete {
                try await automation.hotkey(keys: "delete", holdDuration: 50)
            }
            
            // Press return if requested
            if pressReturn {
                try await automation.hotkey(keys: "return", holdDuration: 50)
            }
            
            let executionTime = Date().timeIntervalSince(startTime)
            
            // Build response message
            var actions: [String] = []
            
            if clear {
                actions.append("Cleared field")
            }
            
            if let text = text {
                let displayText = text.count > 50 ? String(text.prefix(50)) + "..." : text
                actions.append("Typed: \"\(displayText)\"")
            }
            
            if let tabCount = tabCount {
                actions.append("Pressed Tab \(tabCount) time\(tabCount != 1 ? "s" : "")")
            }
            
            if escape {
                actions.append("Pressed Escape")
            }
            
            if delete {
                actions.append("Pressed Delete")
            }
            
            if pressReturn {
                actions.append("Pressed Return")
            }
            
            let message = "✅ " + actions.joined(separator: ", ") + " in \(String(format: "%.2f", executionTime))s"
            
            return ToolResponse(
                content: [.text(message)],
                meta: .object([
                    "execution_time": .double(executionTime),
                    "characters_typed": text != nil ? .double(Double(text!.count)) : .null
                ])
            )
            
        } catch {
            logger.error("Type execution failed: \(error)")
            return ToolResponse.error("Failed to type text: \(error.localizedDescription)")
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