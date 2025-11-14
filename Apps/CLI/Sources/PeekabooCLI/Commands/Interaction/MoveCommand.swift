import AppKit
import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

/// Moves the mouse cursor to specific coordinates or UI elements.
@available(macOS 14.0, *)
@MainActor
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

    @Option(help: "Movement profile: linear (default) or human.")
    var profile: String?

    @Option(help: "Session ID for element resolution")
    var session: String?
    @RuntimeStorage private var runtime: CommandRuntime?

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    private var services: any PeekabooServiceProviding { self.resolvedRuntime.services }
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
                  Double(parts[0]) != nil,
                  Double(parts[1]) != nil else {
                throw ValidationError("Invalid coordinates format. Use: x,y")
            }
        }

        if let profileName = self.profile?.lowercased(),
           MovementProfileSelection(rawValue: profileName) == nil
        {
            throw ValidationError("Invalid profile '\(profileName)'. Use 'linear' or 'human'.")
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
                    throw ValidationError("No main screen found")
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
                    automation: self.services.automation,
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
                throw ValidationError("Specify coordinates, --to, --id, or --center")
            }

            // Get current mouse location for distance calculation
            let currentLocation = CGEvent(source: nil)?.location ?? CGPoint.zero
            let distance = hypot(
                targetLocation.x - currentLocation.x,
                targetLocation.y - currentLocation.y
            )

            let movement = self.resolveMovementParameters(
                profileSelection: self.selectedProfile,
                distance: distance
            )

            // Perform the movement
            try await AutomationServiceBridge.moveMouse(
                automation: self.services.automation,
                to: targetLocation,
                duration: movement.duration,
                steps: movement.steps,
                profile: movement.profile
            )

            // Output results
            let result = MoveResult(
                success: true,
                targetLocation: targetLocation,
                targetDescription: targetDescription,
                fromLocation: currentLocation,
                distance: distance,
                duration: movement.duration,
                smooth: movement.smooth,
                profile: movement.profileName,
                executionTime: Date().timeIntervalSince(startTime)
            )
            output(result) {
                print("✅ Mouse moved successfully")
                print("🎯 Target: \(targetDescription)")
                print("📍 Location: (\(Int(targetLocation.x)), \(Int(targetLocation.y)))")
                print("📏 Distance: \(Int(distance)) pixels")
                print("🧭 Profile: \(movement.profileName.capitalized)")
                if movement.smooth {
                    print("🎬 Animation: \(movement.duration)ms with \(movement.steps) steps")
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

    private var selectedProfile: MovementProfileSelection {
        guard let profileName = self.profile?.lowercased(),
              let selection = MovementProfileSelection(rawValue: profileName) else
        {
            return .linear
        }
        return selection
    }

    private func resolveMovementParameters(
        profileSelection: MovementProfileSelection,
        distance: CGFloat
    ) -> MovementParameters {
        switch profileSelection {
        case .linear:
            let resolvedDuration: Int
            if let customDuration = self.duration {
                resolvedDuration = customDuration
            } else {
                resolvedDuration = self.smooth ? 500 : 0
            }
            let resolvedSteps = self.smooth ? max(self.steps, 1) : 1
            return MovementParameters(
                profile: .linear,
                duration: resolvedDuration,
                steps: resolvedSteps,
                smooth: self.smooth,
                profileName: profileSelection.rawValue
            )
        case .human:
            let resolvedDuration = self.duration ?? self.defaultHumanDuration(for: distance)
            let resolvedSteps = max(self.steps, self.defaultHumanSteps(for: distance))
            return MovementParameters(
                profile: .human(),
                duration: resolvedDuration,
                steps: resolvedSteps,
                smooth: true,
                profileName: profileSelection.rawValue
            )
        }
    }

    private func defaultHumanDuration(for distance: CGFloat) -> Int {
        let distanceFactor = log2(Double(distance) + 1) * 90
        let perPixel = Double(distance) * 0.45
        let estimate = 240 + distanceFactor + perPixel
        return min(max(Int(estimate), 280), 1700)
    }

    private func defaultHumanSteps(for distance: CGFloat) -> Int {
        let scaled = Int(distance * 0.35)
        return min(max(scaled, 30), 120)
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
    let profile: String
    let executionTime: TimeInterval

    init(
        success: Bool,
        targetLocation: CGPoint,
        targetDescription: String,
        fromLocation: CGPoint,
        distance: Double,
        duration: Int,
        smooth: Bool,
        profile: String,
        executionTime: TimeInterval
    ) {
        self.success = success
        self.targetLocation = ["x": targetLocation.x, "y": targetLocation.y]
        self.targetDescription = targetDescription
        self.fromLocation = ["x": fromLocation.x, "y": fromLocation.y]
        self.distance = distance
        self.duration = duration
        self.smooth = smooth
        self.profile = profile
        self.executionTime = executionTime
    }
}

// MARK: - Conformances

@MainActor
extension MoveCommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
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
                      - Human: Natural arcs with eased velocity, enable via '--profile human'

                    ELEMENT TARGETING:
                      When targeting elements, the cursor moves to the element's center.
                      Use element IDs from 'see' output for precise targeting.
                """
                ,
                showHelpOnEmptyInvocation: true
            )
        }
    }
}

extension MoveCommand: AsyncRuntimeCommand {}

@MainActor
extension MoveCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.coordinates = try values.decodeOptionalPositional(0, label: "coordinates")
        self.to = values.singleOption("to")
        self.id = values.singleOption("id")
        self.center = values.flag("center")
        self.smooth = values.flag("smooth")
        if let duration: Int = try values.decodeOption("duration", as: Int.self) {
            self.duration = duration
        }
        if let steps: Int = try values.decodeOption("steps", as: Int.self) {
            self.steps = steps
        }
        self.session = values.singleOption("session")
        self.profile = values.singleOption("profile")
    }
}

private enum MovementProfileSelection: String {
    case linear
    case human
}

private struct MovementParameters {
    let profile: MouseMovementProfile
    let duration: Int
    let steps: Int
    let smooth: Bool
    let profileName: String
}
