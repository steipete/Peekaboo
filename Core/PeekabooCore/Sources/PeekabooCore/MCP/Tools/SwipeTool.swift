import Foundation
import MCP
import os.log

/// MCP tool for performing swipe/drag gestures
public struct SwipeTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "SwipeTool")
    
    public let name = "swipe"
    
    public var description: String {
        """
        Performs a swipe/drag gesture from one point to another.
        Useful for dragging elements, swiping through content, or gesture-based interactions.
        Creates smooth movement with configurable duration.
        Peekaboo MCP 3.0.0-beta.2 using anthropic/claude-opus-4-20250514, ollama/llava:latest
        """
    }
    
    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "from": SchemaBuilder.string(
                    description: "Starting coordinates in format 'x,y' (e.g., '100,200')."
                ),
                "to": SchemaBuilder.string(
                    description: "Ending coordinates in format 'x,y' (e.g., '300,400')."
                ),
                "duration": SchemaBuilder.number(
                    description: "Optional. Duration of the swipe in milliseconds. Default: 500.",
                    default: 500
                ),
                "steps": SchemaBuilder.number(
                    description: "Optional. Number of intermediate steps for smooth movement. Default: 10.",
                    default: 10
                )
            ],
            required: ["from", "to"]
        )
    }
    
    public init() {}
    
    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        // Parse required parameters
        guard let fromString = arguments.getString("from") else {
            return ToolResponse.error("'from' parameter is required")
        }
        
        guard let toString = arguments.getString("to") else {
            return ToolResponse.error("'to' parameter is required")
        }
        
        // Parse optional parameters
        let duration = Int(arguments.getNumber("duration") ?? 500)
        let steps = Int(arguments.getNumber("steps") ?? 10)
        
        // Validate duration
        guard duration > 0 else {
            return ToolResponse.error("Duration must be greater than 0")
        }
        
        guard duration <= 30000 else {
            return ToolResponse.error("Duration must be 30 seconds or less to prevent excessive delays")
        }
        
        // Validate steps
        guard steps > 0 else {
            return ToolResponse.error("Steps must be greater than 0")
        }
        
        guard steps <= 100 else {
            return ToolResponse.error("Steps must be 100 or less to prevent excessive processing")
        }
        
        do {
            let startTime = Date()
            
            // Parse 'from' coordinates
            let fromPoint = try parseCoordinates(fromString, parameterName: "from")
            
            // Parse 'to' coordinates  
            let toPoint = try parseCoordinates(toString, parameterName: "to")
            
            // Validate that from and to are different
            guard fromPoint != toPoint else {
                return ToolResponse.error("'from' and 'to' coordinates must be different")
            }
            
            // Perform the drag/swipe gesture
            let automation = PeekabooServices.shared.automation
            try await automation.drag(
                from: fromPoint,
                to: toPoint,
                duration: duration,
                steps: steps,
                modifiers: nil
            )
            
            let executionTime = Date().timeIntervalSince(startTime)
            
            // Calculate distance for the response
            let deltaX = toPoint.x - fromPoint.x
            let deltaY = toPoint.y - fromPoint.y
            let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
            
            // Build response message
            let message = "✅ Performed swipe from (\(Int(fromPoint.x)), \(Int(fromPoint.y))) to (\(Int(toPoint.x)), \(Int(toPoint.y))) over \(duration)ms with \(steps) steps (distance: \(String(format: "%.1f", distance))px) in \(String(format: "%.2f", executionTime))s"
            
            return ToolResponse(
                content: [.text(message)],
                meta: .object([
                    "from": .object([
                        "x": .double(Double(fromPoint.x)),
                        "y": .double(Double(fromPoint.y))
                    ]),
                    "to": .object([
                        "x": .double(Double(toPoint.x)),
                        "y": .double(Double(toPoint.y))
                    ]),
                    "duration": .double(Double(duration)),
                    "steps": .double(Double(steps)),
                    "distance": .double(distance),
                    "execution_time": .double(executionTime)
                ])
            )
            
        } catch let coordinateError as CoordinateParseError {
            return ToolResponse.error(coordinateError.message)
        } catch {
            logger.error("Swipe execution failed: \(error)")
            return ToolResponse.error("Failed to perform swipe: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helpers
    
    private struct CoordinateParseError: Swift.Error {
        let message: String
    }
    
    private func parseCoordinates(_ coordString: String, parameterName: String) throws -> CGPoint {
        let parts = coordString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        guard parts.count == 2 else {
            throw CoordinateParseError(message: "Invalid \(parameterName) coordinates format. Use 'x,y' (e.g., '100,200')")
        }
        
        guard let x = Double(parts[0]), let y = Double(parts[1]) else {
            throw CoordinateParseError(message: "Invalid \(parameterName) coordinates. Both x and y must be valid numbers")
        }
        
        // Validate coordinates are reasonable (not negative, not extremely large)
        guard x >= 0 && y >= 0 else {
            throw CoordinateParseError(message: "Invalid \(parameterName) coordinates. Both x and y must be non-negative")
        }
        
        guard x <= 10000 && y <= 10000 else {
            throw CoordinateParseError(message: "Invalid \(parameterName) coordinates. Both x and y must be 10000 or less")
        }
        
        return CGPoint(x: x, y: y)
    }
}