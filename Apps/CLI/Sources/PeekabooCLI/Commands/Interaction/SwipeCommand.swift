import AppKit
@preconcurrency import ArgumentParser
import AXorcist
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

/// Performs swipe gestures using intelligent element finding and service-based architecture.
@available(macOS 14.0, *)
@MainActor
struct SwipeCommand {
    static let configuration = CommandConfiguration(
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
    var duration: Int = 500

    @Option(help: "Number of intermediate points for smooth movement")
    var steps: Int = 20

    @Flag(help: "Use right mouse button for drag")
    var rightButton = false

    @OptionGroup var runtimeOptions: CommandRuntimeOptions

    @RuntimeStorage private var runtime: CommandRuntime?

    var outputLogger: Logger {
        self.runtime?.logger ?? Logger.shared
    }

    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        let startTime = Date()
        let services = runtime.services

        do {
            // Validate inputs
            guard self.from != nil || self.fromCoords != nil, self.to != nil || self.toCoords != nil else {
                throw ArgumentParser.ValidationError(
                    "Must specify both source (--from or --from-coords) and destination (--to or --to-coords)"
                )
            }

            // Note: Right-button swipe is not supported in the current implementation
            if self.rightButton {
                throw ArgumentParser
                    .ValidationError(
                        "Right-button swipe is not currently supported. " +
                            "Please use the standard swipe command for right-button gestures."
                    )
            }

            // Determine session ID - use provided or get most recent
            let sessionId: String? = if let providedSession = session {
                providedSession
            } else {
                await services.sessions.getMostRecentSession()
            }

            // Get source and destination points
            let sourcePoint = try await resolvePoint(
                elementId: from,
                coords: fromCoords,
                sessionId: sessionId,
                description: "from",
                waitTimeout: 5.0,
                services: services
            )

            let destPoint = try await resolvePoint(
                elementId: to,
                coords: toCoords,
                sessionId: sessionId,
                description: "to",
                waitTimeout: 5.0,
                services: services
            )

            // Perform swipe using UIAutomationService
            try await services.automation.swipe(
                from: sourcePoint,
                to: destPoint,
                duration: self.duration,
                steps: self.steps
            )

            // Calculate distance for output
            let distance = sqrt(pow(destPoint.x - sourcePoint.x, 2) + pow(destPoint.y - sourcePoint.y, 2))

            // Small delay to ensure swipe is processed
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            // Output results
            if self.jsonOutput {
                let output = SwipeResult(
                    success: true,
                    fromLocation: ["x": sourcePoint.x, "y": sourcePoint.y],
                    toLocation: ["x": destPoint.x, "y": destPoint.y],
                    distance: distance,
                    duration: self.duration,
                    executionTime: Date().timeIntervalSince(startTime)
                )
                outputSuccessCodable(data: output, logger: self.outputLogger)
            } else {
                print("✅ Swipe completed")
                print("📍 From: (\(Int(sourcePoint.x)), \(Int(sourcePoint.y)))")
                print("📍 To: (\(Int(destPoint.x)), \(Int(destPoint.y)))")
                print("📏 Distance: \(Int(distance)) pixels")
                print("⏱️  Duration: \(self.duration)ms")
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
        waitTimeout: TimeInterval,
        services: PeekabooServices
    ) async throws -> CGPoint {
        if let coordString = coords {
            // Parse coordinates
            let parts = coordString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2,
                  let x = Double(parts[0]),
                  let y = Double(parts[1])
            else {
                throw ArgumentParser.ValidationError("Invalid coordinates format: '\(coordString)'. Expected 'x,y'")
            }
            return CGPoint(x: x, y: y)
        } else if let element = elementId, let activeSessionId = sessionId {
            // Resolve from session using waitForElement
            let target = ClickTarget.elementId(element)
            let waitResult = try await services.automation.waitForElement(
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

    private func handleError(_ error: any Error) {
        if self.jsonOutput {
            let errorCode: ErrorCode
            let message: String

            if let peekabooError = error as? PeekabooError {
                switch peekabooError {
                case .sessionNotFound:
                    errorCode = .SESSION_NOT_FOUND
                    message = "Session not found"
                case .elementNotFound:
                    errorCode = .ELEMENT_NOT_FOUND
                    message = "Element not found"
                case let .clickFailed(msg):
                    errorCode = .INTERACTION_FAILED
                    message = msg
                case let .typeFailed(msg):
                    errorCode = .INTERACTION_FAILED
                    message = msg
                default:
                    errorCode = .INTERNAL_SWIFT_ERROR
                    message = error.localizedDescription
                }
            } else if error is ArgumentParser.ValidationError {
                errorCode = .INVALID_INPUT
                message = error.localizedDescription
            } else {
                errorCode = .INTERNAL_SWIFT_ERROR
                message = error.localizedDescription
            }

            outputError(message: message, code: errorCode)
        } else {
            var localStandardErrorStream = FileHandleTextOutputStream(FileHandle.standardError)
            print("❌ Error: \(error.localizedDescription)", to: &localStandardErrorStream)
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
    let executionTime: TimeInterval
}

@MainActor
extension SwipeCommand: AsyncRuntimeCommand {}
