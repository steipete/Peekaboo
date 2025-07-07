import AppKit
import ArgumentParser
import CoreGraphics
import Foundation
import PeekabooCore

/// Refactored MoveCommand using PeekabooCore services
/// Moves the mouse cursor to specific coordinates or UI elements.
@available(macOS 14.0, *)
struct MoveCommandV2: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "move-v2",
        abstract: "Move the mouse cursor to coordinates or UI elements using PeekabooCore services",
        discussion: """
            This is a refactored version of the move command that uses PeekabooCore services
            instead of direct implementation. It maintains the same interface but delegates
            all operations to the service layer.
            
            The 'move' command positions the mouse cursor at specific locations or
            on UI elements detected by 'see'. Supports instant and smooth movement.

            EXAMPLES:
              peekaboo move-v2 100,200                 # Move to coordinates
              peekaboo move-v2 --to "Submit Button"    # Move to element by text
              peekaboo move-v2 --id B3                 # Move to element by ID
              peekaboo move-v2 500,300 --smooth        # Smooth movement
              peekaboo move-v2 --center                # Move to screen center

            MOVEMENT MODES:
              - Instant (default): Immediate cursor positioning
              - Smooth: Animated movement with configurable duration

            ELEMENT TARGETING:
              When targeting elements, the cursor moves to the element's center.
              Use element IDs from 'see' output for precise targeting.
        """)

    @Argument(help: "Coordinates as x,y (e.g., 100,200)")
    var coordinates: String?

    @Option(help: "Move to element by text/label")
    var to: String?

    @Option(help: "Move to element by ID (e.g., B1, T2)")
    var id: String?

    @Flag(help: "Move to screen center")
    var center = false

    @Flag(help: "Use smooth movement animation")
    var smooth = false

    @Option(help: "Movement duration in milliseconds (default: 500 for smooth, 0 for instant)")
    var duration: Int?

    @Option(help: "Number of steps for smooth movement (default: 20)")
    var steps: Int = 20

    @Option(help: "Session ID for element resolution")
    var session: String?

    @Flag(help: "Output in JSON format")
    var jsonOutput = false

    private let services = PeekabooServices.shared

    mutating func run() async throws {
        let startTime = Date()
        Logger.shared.setJsonOutputMode(jsonOutput)

        do {
            // Determine target location
            let targetLocation: CGPoint
            let targetDescription: String

            if center {
                // Move to screen center
                guard let mainScreen = NSScreen.main else {
                    throw ValidationError("No main screen found")
                }
                let screenFrame = mainScreen.frame
                targetLocation = CGPoint(x: screenFrame.midX, y: screenFrame.midY)
                targetDescription = "Screen center"
                
            } else if let coordString = coordinates {
                // Parse coordinates
                let parts = coordString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2,
                      let x = Double(parts[0]),
                      let y = Double(parts[1])
                else {
                    throw ValidationError("Invalid coordinates format. Use: x,y")
                }
                targetLocation = CGPoint(x: x, y: y)
                targetDescription = "Coordinates (\(Int(x)), \(Int(y)))"
                
            } else if let elementId = id {
                // Move to element by ID
                let sessionId = session ?? (await services.sessions.getMostRecentSession())
                guard let activeSessionId = sessionId else {
                    throw PeekabooError.sessionNotFound
                }
                
                guard let detectionResult = try? await services.sessions.getDetectionResult(sessionId: activeSessionId),
                      let element = detectionResult.elements.findById(elementId) else {
                    throw PeekabooError.elementNotFound
                }
                
                targetLocation = CGPoint(x: element.bounds.midX, y: element.bounds.midY)
                targetDescription = formatElementInfo(element)
                
            } else if let query = to {
                // Find element by text/query
                let sessionId = session ?? (await services.sessions.getMostRecentSession())
                guard let activeSessionId = sessionId else {
                    throw PeekabooError.sessionNotFound
                }
                
                // Wait for element to be available
                let waitResult = try await services.automation.waitForElement(
                    target: .query(query),
                    timeout: 5.0,
                    sessionId: activeSessionId
                )
                
                guard waitResult.found, let element = waitResult.element else {
                    throw PeekabooError.interactionFailed(
                        "No element found matching '\(query)'"
                    )
                }
                
                targetLocation = CGPoint(x: element.bounds.midX, y: element.bounds.midY)
                targetDescription = formatElementInfo(element)
                
            } else {
                throw ValidationError("Specify coordinates, --to, --id, or --center")
            }

            // Determine movement duration
            let moveDuration: Int
            if let customDuration = duration {
                moveDuration = customDuration
            } else {
                moveDuration = smooth ? 500 : 0
            }

            // Get current mouse location for distance calculation
            let currentLocation = CGEvent(source: nil)?.location ?? CGPoint.zero
            let distance = hypot(targetLocation.x - currentLocation.x, 
                               targetLocation.y - currentLocation.y)

            // Perform the movement
            try await services.automation.moveMouse(
                to: targetLocation,
                duration: moveDuration,
                steps: smooth ? steps : 1
            )

            // Output results
            if jsonOutput {
                let result = MoveResult(
                    success: true,
                    targetLocation: targetLocation,
                    targetDescription: targetDescription,
                    fromLocation: currentLocation,
                    distance: distance,
                    duration: moveDuration,
                    smooth: smooth,
                    executionTime: Date().timeIntervalSince(startTime)
                )
                outputSuccessCodable(data: result)
            } else {
                print("✅ Mouse moved successfully")
                print("🎯 Target: \(targetDescription)")
                print("📍 Location: (\(Int(targetLocation.x)), \(Int(targetLocation.y)))")
                print("📏 Distance: \(Int(distance)) pixels")
                if smooth {
                    print("🎬 Animation: \(moveDuration)ms with \(steps) steps")
                }
                print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
            }

        } catch {
            handleError(error)
            throw ExitCode.failure
        }
    }

    private func formatElementInfo(_ element: DetectedElement) -> String {
        let roleDescription = element.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        let label = element.label ?? element.value ?? element.id
        return "\(roleDescription): \(label)"
    }

    private func handleError(_ error: Error) {
        if jsonOutput {
            let errorCode: ErrorCode
            if error is PeekabooError {
                switch error as? PeekabooError {
                case .sessionNotFound:
                    errorCode = .SESSION_NOT_FOUND
                case .elementNotFound:
                    errorCode = .ELEMENT_NOT_FOUND
                case .interactionFailed:
                    errorCode = .INTERACTION_FAILED
                default:
                    errorCode = .INTERNAL_SWIFT_ERROR
                }
            } else if error is ValidationError {
                errorCode = .INVALID_INPUT
            } else if let uiError = error as? UIAutomationError {
                switch uiError {
                case .mouseMoveFailed:
                    errorCode = .INTERACTION_FAILED
                default:
                    errorCode = .INTERNAL_SWIFT_ERROR
                }
            } else {
                errorCode = .INTERNAL_SWIFT_ERROR
            }
            
            outputError(
                message: error.localizedDescription,
                code: errorCode
            )
        } else {
            var localStandardErrorStream = FileHandleTextOutputStream(FileHandle.standardError)
            print("Error: \(error.localizedDescription)", to: &localStandardErrorStream)
        }
    }
}

// MARK: - JSON Output Structure

struct MoveResult: Codable {
    let success: Bool
    let targetLocation: [String: Double]
    let targetDescription: String
    let fromLocation: [String: Double]
    let distance: Double
    let duration: Int
    let smooth: Bool
    let executionTime: TimeInterval

    init(
        success: Bool,
        targetLocation: CGPoint,
        targetDescription: String,
        fromLocation: CGPoint,
        distance: Double,
        duration: Int,
        smooth: Bool,
        executionTime: TimeInterval)
    {
        self.success = success
        self.targetLocation = ["x": targetLocation.x, "y": targetLocation.y]
        self.targetDescription = targetDescription
        self.fromLocation = ["x": fromLocation.x, "y": fromLocation.y]
        self.distance = distance
        self.duration = duration
        self.smooth = smooth
        self.executionTime = executionTime
    }
}