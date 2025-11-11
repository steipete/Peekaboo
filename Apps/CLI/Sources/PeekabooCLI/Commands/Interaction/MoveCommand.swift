import AppKit
@preconcurrency import ArgumentParser
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

/// Moves the mouse cursor to specific coordinates or UI elements.
@available(macOS 14.0, *)
struct MoveCommand: ErrorHandlingCommand, OutputFormattable {

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

    @OptionGroup var runtimeOptions: CommandRuntimeOptions

    @RuntimeStorage private var runtime: CommandRuntime?

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var services: PeekabooServices { self.resolvedRuntime.services }
    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }
    var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

    mutating func validate() throws {
        // Ensure at least one target is specified
        guard self.center || self.coordinates != nil || self.to != nil || self.id != nil else {
            throw ValidationError("Specify coordinates, --to, --id, or --center")
        }

        // Validate coordinates format if provided
        if let coordString = coordinates {
            let parts = coordString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2,
                  let _ = Double(parts[0]),
                  let _ = Double(parts[1])
            else {
                throw ValidationError("Invalid coordinates format. Use: x,y")
            }
        }
    }

    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        let startTime = Date()
        self.logger.setJsonOutputMode(self.jsonOutput)

        do {
            // Determine target location
            let targetLocation: CGPoint
            let targetDescription: String

            if self.center {
                // Move to screen center
                guard let mainScreen = NSScreen.main else {
                    throw ArgumentParser.ValidationError("No main screen found")
                }
                let screenFrame = mainScreen.frame
                targetLocation = CGPoint(x: screenFrame.midX, y: screenFrame.midY)
                targetDescription = "Screen center"

            } else if let coordString = coordinates {
                // Parse coordinates
                let parts = coordString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                let x = Double(parts[0])!
                let y = Double(parts[1])!
                targetLocation = CGPoint(x: x, y: y)
                targetDescription = "Coordinates (\(Int(x)), \(Int(y)))"

            } else if let elementId = id {
                // Move to element by ID
                let sessionId: String? = if let providedSession = session {
                    providedSession
                } else {
                    await self.services.sessions.getMostRecentSession()
                }
                guard let activeSessionId = sessionId else {
                    throw PeekabooError.sessionNotFound("No session found")
                }

                guard let detectionResult = try? await self.services.sessions
                    .getDetectionResult(sessionId: activeSessionId),
                    let element = detectionResult.elements.findById(elementId)
                else {
                    throw PeekabooError.elementNotFound("Element with ID '\(elementId)' not found")
                }

                targetLocation = CGPoint(x: element.bounds.midX, y: element.bounds.midY)
                targetDescription = self.formatElementInfo(element)

            } else if let query = to {
                // Find element by text/query
                let sessionId: String? = if let providedSession = session {
                    providedSession
                } else {
                    await self.services.sessions.getMostRecentSession()
                }
                guard let activeSessionId = sessionId else {
                    throw PeekabooError.sessionNotFound("No session found")
                }

                // Wait for element to be available
                let waitResult = try await AutomationServiceBridge.waitForElement(
                    services: self.services,
                    target: .query(query),
                    timeout: 5.0,
                    sessionId: activeSessionId
                )

                guard waitResult.found, let element = waitResult.element else {
                    throw PeekabooError.elementNotFound(
                        "No element found matching '\(query)'"
                    )
                }

                targetLocation = CGPoint(x: element.bounds.midX, y: element.bounds.midY)
                targetDescription = self.formatElementInfo(element)

            } else {
                throw ArgumentParser.ValidationError("Specify coordinates, --to, --id, or --center")
            }

            // Determine movement duration
            let moveDuration: Int = if let customDuration = duration {
                customDuration
            } else {
                self.smooth ? 500 : 0
            }

            // Get current mouse location for distance calculation
            let currentLocation = CGEvent(source: nil)?.location ?? CGPoint.zero
            let distance = hypot(
                targetLocation.x - currentLocation.x,
                targetLocation.y - currentLocation.y
            )

            // Perform the movement
            try await AutomationServiceBridge.moveMouse(
                services: self.services,
                to: targetLocation,
                duration: moveDuration,
                steps: self.smooth ? self.steps : 1
            )

            // Output results
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
            output(result) {
                print("✅ Mouse moved successfully")
                print("🎯 Target: \(targetDescription)")
                print("📍 Location: (\(Int(targetLocation.x)), \(Int(targetLocation.y)))")
                print("📏 Distance: \(Int(distance)) pixels")
                if self.smooth {
                    print("🎬 Animation: \(moveDuration)ms with \(self.steps) steps")
                }
                print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
            }

        } catch {
            self.handleError(error)
            throw ExitCode.failure
        }
    }

    private func formatElementInfo(_ element: DetectedElement) -> String {
        let roleDescription = element.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        let label = element.label ?? element.value ?? element.id
        return "\(roleDescription): \(label)"
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
        executionTime: TimeInterval
    ) {
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

// MARK: - Conformances

extension MoveCommand: ParsableCommand {
    nonisolated(unsafe) static var configuration: CommandConfiguration {
        MainActorCommandConfiguration.describe {
            CommandConfiguration(
                commandName: "move",
                abstract: "Move the mouse cursor to coordinates or UI elements",
                discussion: """
            The 'move' command positions the mouse cursor at specific locations or
            on UI elements detected by 'see'. Supports instant and smooth movement.

            EXAMPLES:
              peekaboo move 100,200                 # Move to coordinates
              peekaboo move --to "Submit Button"    # Move to element by text
              peekaboo move --id B3                 # Move to element by ID
              peekaboo move 500,300 --smooth        # Smooth movement
              peekaboo move --center                # Move to screen center

            MOVEMENT MODES:
              - Instant (default): Immediate cursor positioning
              - Smooth: Animated movement with configurable duration

            ELEMENT TARGETING:
              When targeting elements, the cursor moves to the element's center.
              Use element IDs from 'see' output for precise targeting.
        """
            )
        }
    }
}

extension MoveCommand: AsyncRuntimeCommand {}
