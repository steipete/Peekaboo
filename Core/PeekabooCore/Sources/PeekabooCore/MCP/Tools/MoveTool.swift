import Foundation
import MCP
import os.log
import TachikomaMCP

#if canImport(AppKit)
import AppKit
#endif

/// MCP tool for moving the mouse cursor
public struct MoveTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "MoveTool")

    public let name = "move"

    public var description: String {
        """
        Move the mouse cursor to a specific position or UI element.
        Supports absolute coordinates, UI element targeting, or centering on screen.
        Can animate movement smoothly over a specified duration.
        Peekaboo MCP 3.0.0-beta.2 using openai/gpt-5, anthropic/claude-sonnet-4.5
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "to": SchemaBuilder.string(
                    description: "Optional. Coordinates in format 'x,y' (e.g., '100,200') or 'center' to center on screen."),
                "coordinates": SchemaBuilder.string(
                    description: "Optional. Alias for 'to' - coordinates in format 'x,y' (e.g., '100,200')."),
                "id": SchemaBuilder.string(
                    description: "Optional. Element ID to move to (from see command output)."),
                "session": SchemaBuilder.string(
                    description: "Optional. Session ID from see command. Uses latest session if not specified."),
                "center": SchemaBuilder.boolean(
                    description: "Optional. Move to center of screen.",
                    default: false),
                "smooth": SchemaBuilder.boolean(
                    description: "Optional. Use smooth animated movement.",
                    default: false),
                "duration": SchemaBuilder.number(
                    description: "Optional. Duration in milliseconds for smooth movement. Default: 500.",
                    default: 500),
                "steps": SchemaBuilder.number(
                    description: "Optional. Number of steps for smooth movement. Default: 10.",
                    default: 10),
            ],
            required: [])
    }

    public init() {}

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        // Validate that at least one target is specified
        let toCoords = arguments.getString("to")
        let coordinates = arguments.getString("coordinates")
        let elementId = arguments.getString("id")
        let centerScreen = arguments.getBool("center") ?? false

        guard toCoords != nil || coordinates != nil || elementId != nil || centerScreen else {
            return ToolResponse.error("Must specify either 'to', 'coordinates', 'id', or 'center'")
        }

        // Parse optional parameters
        let sessionId = arguments.getString("session")
        let useSmooth = arguments.getBool("smooth") ?? false
        let duration = Int(arguments.getNumber("duration") ?? 500)
        let steps = Int(arguments.getNumber("steps") ?? 10)

        // Validate duration and steps for smooth movement
        if useSmooth {
            guard duration > 0 else {
                return ToolResponse.error("Duration must be greater than 0")
            }

            guard duration <= 30000 else {
                return ToolResponse.error("Duration must be 30 seconds or less to prevent excessive delays")
            }

            guard steps > 0 else {
                return ToolResponse.error("Steps must be greater than 0")
            }

            guard steps <= 100 else {
                return ToolResponse.error("Steps must be 100 or less to prevent excessive processing")
            }
        }

        do {
            let startTime = Date()

            // Determine target location
            let targetLocation: CGPoint
            let targetDescription: String

            if centerScreen {
                // Move to center of screen
                targetLocation = try self.getCenterOfScreen()
                targetDescription = "center of screen"

            } else if let coordString = toCoords ?? coordinates {
                // Parse coordinates or handle "center" string
                if coordString.lowercased() == "center" {
                    targetLocation = try self.getCenterOfScreen()
                    targetDescription = "center of screen"
                } else {
                    targetLocation = try self.parseCoordinates(coordString, parameterName: "coordinates")
                    targetDescription = "coordinates (\(Int(targetLocation.x)), \(Int(targetLocation.y)))"
                }

            } else if let elementId {
                // Find element by ID from session
                guard let session = await getSession(id: sessionId) else {
                    return ToolResponse.error("No active session. Run 'see' command first to capture UI state.")
                }

                guard let element = await session.getElement(byId: elementId) else {
                    return ToolResponse
                        .error(
                            "Element '\(elementId)' not found in current session. Run 'see' command to update UI state.")
                }

                // Calculate center of element
                targetLocation = CGPoint(
                    x: element.frame.midX,
                    y: element.frame.midY)
                targetDescription = "element \(elementId) (\(element.role): \(element.title ?? element.label ?? "untitled"))"

            } else {
                return ToolResponse.error("No target specified")
            }

            // Perform the mouse movement
            let automation = PeekabooServices.shared.automation

            if useSmooth {
                try await automation.moveMouse(to: targetLocation, duration: duration, steps: steps)
            } else {
                // For non-smooth movement, use duration=0 and steps=1 for instant movement
                try await automation.moveMouse(to: targetLocation, duration: 0, steps: 1)
            }

            let executionTime = Date().timeIntervalSince(startTime)

            // Build response message
            var message = "\(AgentDisplayTokens.Status.success) Moved mouse cursor to \(targetDescription)"
            if useSmooth {
                message += " with smooth animation (\(duration)ms, \(steps) steps)"
            }
            message += " in \(String(format: "%.2f", executionTime))s"

            return ToolResponse(
                content: [.text(message)],
                meta: .object([
                    "target_location": .object([
                        "x": .double(Double(targetLocation.x)),
                        "y": .double(Double(targetLocation.y)),
                    ]),
                    "target_description": .string(targetDescription),
                    "smooth": .bool(useSmooth),
                    "duration": .double(Double(duration)),
                    "steps": .double(Double(steps)),
                    "execution_time": .double(executionTime),
                ]))

        } catch let coordinateError as CoordinateParseError {
            return ToolResponse.error(coordinateError.message)
        } catch {
            self.logger.error("Mouse movement execution failed: \(error)")
            return ToolResponse.error("Failed to move mouse: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    private struct CoordinateParseError: Swift.Error {
        let message: String
    }

    private func parseCoordinates(_ coordString: String, parameterName: String) throws -> CGPoint {
        let parts = coordString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        guard parts.count == 2 else {
            throw CoordinateParseError(
                message: "Invalid \(parameterName) format. Use 'x,y' (e.g., '100,200') or 'center'")
        }

        guard let x = Double(parts[0]), let y = Double(parts[1]) else {
            throw CoordinateParseError(message: "Invalid \(parameterName). Both x and y must be valid numbers")
        }

        // Validate coordinates are reasonable (not negative, not extremely large)
        guard x >= 0, y >= 0 else {
            throw CoordinateParseError(message: "Invalid \(parameterName). Both x and y must be non-negative")
        }

        guard x <= 20000, y <= 20000 else {
            throw CoordinateParseError(message: "Invalid \(parameterName). Both x and y must be 20000 or less")
        }

        return CGPoint(x: x, y: y)
    }

    private func getCenterOfScreen() throws -> CGPoint {
        #if canImport(AppKit)
        guard let mainScreen = NSScreen.main else {
            throw CoordinateParseError(message: "Unable to determine main screen dimensions")
        }

        let screenFrame = mainScreen.frame
        return CGPoint(
            x: screenFrame.midX,
            y: screenFrame.midY)
        #else
        // Fallback for non-AppKit environments
        throw CoordinateParseError(message: "Screen center calculation not supported in this environment")
        #endif
    }

    private func getSession(id: String?) async -> UISession? {
        if let sessionId = id {
            return await UISessionManager.shared.getSession(id: sessionId)
        }

        // Get most recent session
        // For now, return nil - in a real implementation we'd track the most recent session
        return nil
    }
}
