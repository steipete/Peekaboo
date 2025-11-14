import AppKit
import AXorcist
import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

/// Performs swipe gestures using intelligent element finding and service-based architecture.
@available(macOS 14.0, *)
@MainActor
struct SwipeCommand: ErrorHandlingCommand, OutputFormattable, RuntimeOptionsConfigurable {
    @Option(help: "Source element ID")
    var from: String?

    @Option(help: "Source coordinates (x,y)")
    var fromCoords: String?

    @Option(help: "Destination element ID")
    var to: String?

    @Option(help: "Destination coordinates (x,y)")
    var toCoords: String?

    @Option(help: "Session ID (uses latest if not specified)")
    var session: String?

    @Option(help: "Duration of the swipe in milliseconds")
    var duration: Int?

    @Option(help: "Number of intermediate points for smooth movement")
    var steps: Int?

    @Option(help: "Movement profile (linear or human)")
    var profile: String?

    @Flag(help: "Use right mouse button for drag")
    var rightButton = false
    @RuntimeStorage private var runtime: CommandRuntime?
    var runtimeOptions = CommandRuntimeOptions()

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var services: any PeekabooServiceProviding { self.resolvedRuntime.services }
    private var logger: Logger { self.resolvedRuntime.logger }
    var outputLogger: Logger { self.logger }
    var jsonOutput: Bool { self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput }

    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        let startTime = Date()
        self.logger.setJsonOutputMode(self.jsonOutput)

        do {
            // Validate inputs
            guard self.from != nil || self.fromCoords != nil, self.to != nil || self.toCoords != nil else {
                throw ValidationError(
                    "Must specify both source (--from or --from-coords) and destination (--to or --to-coords)"
                )
            }

            // Note: Right-button swipe is not supported in the current implementation
            if self.rightButton {
                throw ValidationError(
                    "Right-button swipe is not currently supported. " +
                        "Please use the standard swipe command for right-button gestures."
                )
            }

            if let profileName = self.profile?.lowercased(),
               CursorMovementProfileSelection(rawValue: profileName) == nil
            {
                throw ValidationError("Invalid profile '\(profileName)'. Use 'linear' or 'human'.")
            }

            // Determine session ID - use provided or get most recent
            let sessionId: String? = if let providedSession = session {
                providedSession
            } else {
                await self.services.sessions.getMostRecentSession()
            }

            // Get source and destination points
            let sourcePoint = try await resolvePoint(
                elementId: from,
                coords: fromCoords,
                sessionId: sessionId,
                description: "from",
                waitTimeout: 5.0
            )

            let destPoint = try await resolvePoint(
                elementId: to,
                coords: toCoords,
                sessionId: sessionId,
                description: "to",
                waitTimeout: 5.0
            )

            let distance = hypot(destPoint.x - sourcePoint.x, destPoint.y - sourcePoint.y)
            let profileSelection = CursorMovementProfileSelection(
                rawValue: (self.profile ?? "linear").lowercased()
            ) ?? .linear
            let movement = CursorMovementResolver.resolve(
                selection: profileSelection,
                durationOverride: self.duration,
                stepsOverride: self.steps,
                baseSmooth: true,
                distance: distance,
                defaultDuration: 500,
                defaultSteps: 20
            )

            // Perform swipe using UIAutomationService
            try await AutomationServiceBridge.swipe(
                automation: self.services.automation,
                from: sourcePoint,
                to: destPoint,
                duration: movement.duration,
                steps: movement.steps,
                profile: movement.profile
            )

            // Small delay to ensure swipe is processed
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            let outputPayload = SwipeResult(
                success: true,
                fromLocation: ["x": sourcePoint.x, "y": sourcePoint.y],
                toLocation: ["x": destPoint.x, "y": destPoint.y],
                distance: distance,
                duration: movement.duration,
                steps: movement.steps,
                profile: movement.profileName,
                executionTime: Date().timeIntervalSince(startTime)
            )
            output(outputPayload) {
                print("✅ Swipe completed")
                print("📍 From: (\(Int(sourcePoint.x)), \(Int(sourcePoint.y)))")
                print("📍 To: (\(Int(destPoint.x)), \(Int(destPoint.y)))")
                print("📏 Distance: \(Int(distance)) pixels")
                print("🧭 Profile: \(movement.profileName.capitalized)")
                print("⏱️  Duration: \(movement.duration)ms with \(movement.steps) steps")
                print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
            }

        } catch {
            self.handleError(error)
            throw ExitCode.failure
        }
    }

    private func resolvePoint(
        elementId: String?,
        coords: String?,
        sessionId: String?,
        description: String,
        waitTimeout: TimeInterval
    ) async throws -> CGPoint {
        if let coordString = coords {
            // Parse coordinates
            let parts = coordString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2,
                  let x = Double(parts[0]),
                  let y = Double(parts[1])
            else {
                throw ValidationError("Invalid coordinates format: '\(coordString)'. Expected 'x,y'")
            }
            return CGPoint(x: x, y: y)
        } else if let element = elementId, let activeSessionId = sessionId {
            // Resolve from session using waitForElement
            let target = ClickTarget.elementId(element)
            let waitResult = try await AutomationServiceBridge.waitForElement(
                automation: self.services.automation,
                target: target,
                timeout: waitTimeout,
                sessionId: activeSessionId
            )

            if !waitResult.found {
                throw PeekabooError.elementNotFound("Element with ID '\(element)' not found")
            }

            guard let foundElement = waitResult.element else {
                throw PeekabooError.elementNotFound("Element '\(element)' found but has no bounds")
            }

            // Return center of element
            return CGPoint(
                x: foundElement.bounds.origin.x + foundElement.bounds.width / 2,
                y: foundElement.bounds.origin.y + foundElement.bounds.height / 2
            )
        } else if elementId != nil {
            throw ValidationError("Session ID required when using element IDs")
        } else {
            throw ValidationError("No \(description) point specified")
        }
    }
}

// MARK: - JSON Output Structure

struct SwipeResult: Codable {
    let success: Bool
    let fromLocation: [String: Double]
    let toLocation: [String: Double]
    let distance: Double
    let duration: Int
    let steps: Int
    let profile: String
    let executionTime: TimeInterval
}

// MARK: - Conformances

@MainActor
extension SwipeCommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "swipe",
                abstract: "Perform swipe gestures",
                discussion: """
                Performs a drag/swipe gesture between two points or elements.
                Useful for drag-and-drop operations and gesture-based interactions.

                EXAMPLES:
                  # Swipe between UI elements
                  peekaboo swipe --from B1 --to B5 --session-id 12345

                  # Swipe with coordinates
                  peekaboo swipe --from-coords 100,200 --to-coords 300,400

                  # Mixed mode: element to coordinates
                  peekaboo swipe --from T1 --to-coords 500,300 --duration 1000

                  # Slow swipe for precise gesture
                  peekaboo swipe --from-coords 50,50 --to-coords 400,400 --duration 2000

                USAGE:
                  You can specify source and destination using either:
                  - Element IDs from a previous 'see' command
                  - Direct coordinates
                  - A mix of both

                  The swipe includes a configurable duration to control the
                  speed of the drag gesture.
                """,
                version: "2.0.0"
            )
        }
    }
}

extension SwipeCommand: AsyncRuntimeCommand {}

@MainActor
extension SwipeCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.from = values.singleOption("from")
        self.fromCoords = values.singleOption("fromCoords")
        self.to = values.singleOption("to")
        self.toCoords = values.singleOption("toCoords")
        self.session = values.singleOption("session")
        if let duration: Int = try values.decodeOption("duration", as: Int.self) {
            self.duration = duration
        }
        if let steps: Int = try values.decodeOption("steps", as: Int.self) {
            self.steps = steps
        }
        self.profile = values.singleOption("profile")
        self.rightButton = values.flag("rightButton")
    }
}
