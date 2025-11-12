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
                    description: "Optional. Coordinates in format 'x,y' (e.g., '100,200') " +
                        "or 'center' to center on screen."),
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
        do {
            let request = try self.parseRequest(arguments: arguments)
            let startTime = Date()
            let target = try await self.resolveMoveTarget(request: request)
            try await self.performMovement(to: target.location, request: request)
            let executionTime = Date().timeIntervalSince(startTime)
            return self.buildResponse(
                target: target,
                request: request,
                executionTime: executionTime)
        } catch let error as MoveToolValidationError {
            return ToolResponse.error(error.message)
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

    private func parseRequest(arguments: ToolArguments) throws -> MoveRequest {
        let target = try self.parseTarget(from: arguments)
        let sessionId = arguments.getString("session")
        let smooth = arguments.getBool("smooth") ?? false
        let duration = Int(arguments.getNumber("duration") ?? 500)
        let steps = Int(arguments.getNumber("steps") ?? 10)

        if smooth {
            try self.validateSmoothParameters(duration: duration, steps: steps)
        }

        return MoveRequest(
            target: target,
            sessionId: sessionId,
            smooth: smooth,
            duration: duration,
            steps: steps)
    }

    private func parseTarget(from arguments: ToolArguments) throws -> MoveTarget {
        if arguments.getBool("center") ?? false {
            return .center
        }

        if let elementId = arguments.getString("id") {
            return .element(elementId)
        }

        if let coordinate = arguments.getString("to") ?? arguments.getString("coordinates") {
            return coordinate.lowercased() == "center" ? .center : .coordinates(coordinate)
        }

        throw MoveToolValidationError("Must specify either 'to', 'coordinates', 'id', or 'center'")
    }

    private func validateSmoothParameters(duration: Int, steps: Int) throws {
        guard duration > 0 else {
            throw MoveToolValidationError("Duration must be greater than 0")
        }
        guard duration <= 30000 else {
            throw MoveToolValidationError("Duration must be 30 seconds or less to prevent excessive delays")
        }
        guard steps > 0 else {
            throw MoveToolValidationError("Steps must be greater than 0")
        }
        guard steps <= 100 else {
            throw MoveToolValidationError("Steps must be 100 or less to prevent excessive processing")
        }
    }

    @MainActor
    private func resolveMoveTarget(request: MoveRequest) async throws -> ResolvedMoveTarget {
        switch request.target {
        case .center:
            let location = try self.getCenterOfScreen()
            return ResolvedMoveTarget(location: location, description: "center of screen")
        case let .coordinates(value):
            let location = try self.parseCoordinates(value, parameterName: "coordinates")
            let summary = "coordinates (\(Int(location.x)), \(Int(location.y)))"
            return ResolvedMoveTarget(location: location, description: summary)
        case let .element(elementId):
            guard let session = await self.getSession(id: request.sessionId) else {
                throw MoveToolValidationError("No active session. Run 'see' command first to capture UI state.")
            }
            guard let element = await session.getElement(byId: elementId) else {
                throw MoveToolValidationError(
                    "Element '\(elementId)' not found in current session. Run 'see' command to update UI state.")
            }
            let location = CGPoint(x: element.frame.midX, y: element.frame.midY)
            let label = element.title ?? element.label ?? "untitled"
            let summary = "element \(elementId) (\(element.role): \(label))"
            return ResolvedMoveTarget(location: location, description: summary)
        }
    }

    private func performMovement(to location: CGPoint, request: MoveRequest) async throws {
        let automation = PeekabooServices.shared.automation
        if request.smooth {
            try await automation.moveMouse(to: location, duration: request.duration, steps: request.steps)
        } else {
            try await automation.moveMouse(to: location, duration: 0, steps: 1)
        }
    }

    private func buildResponse(
        target: ResolvedMoveTarget,
        request: MoveRequest,
        executionTime: TimeInterval) -> ToolResponse
    {
        var message = "\(AgentDisplayTokens.Status.success) Moved mouse cursor to \(target.description)"
        if request.smooth {
            message += " with smooth animation (\(request.duration)ms, \(request.steps) steps)"
        }
        message += " in \(String(format: "%.2f", executionTime))s"

        return ToolResponse(
            content: [.text(message)],
            meta: .object([
                "target_location": .object([
                    "x": .double(Double(target.location.x)),
                    "y": .double(Double(target.location.y)),
                ]),
                "target_description": .string(target.description),
                "smooth": .bool(request.smooth),
                "duration": request.smooth ? .double(Double(request.duration)) : .null,
                "steps": request.smooth ? .double(Double(request.steps)) : .null,
                "execution_time": .double(executionTime),
            ]))
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

private enum MoveTarget {
    case center
    case coordinates(String)
    case element(String)
}

private struct MoveRequest {
    let target: MoveTarget
    let sessionId: String?
    let smooth: Bool
    let duration: Int
    let steps: Int
}

private struct ResolvedMoveTarget {
    let location: CGPoint
    let description: String
}

private struct MoveToolValidationError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}
