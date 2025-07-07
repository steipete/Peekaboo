import ArgumentParser
import CoreGraphics
import Foundation
import PeekabooCore

/// Refactored ScrollCommand using PeekabooCore services
/// Scrolls the mouse wheel in a specified direction.
/// Supports scrolling on specific elements or at the current mouse position.
@available(macOS 14.0, *)
struct ScrollCommandV2: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scroll-v2",
        abstract: "Scroll the mouse wheel in any direction using PeekabooCore services",
        discussion: """
            This is a refactored version of the scroll command that uses PeekabooCore services
            instead of direct implementation. It maintains the same interface but delegates
            all operations to the service layer.
            
            The 'scroll' command simulates mouse wheel scrolling events.
            It can scroll up, down, left, or right by a specified amount.

            EXAMPLES:
              peekaboo scroll-v2 --direction down --amount 5
              peekaboo scroll-v2 --direction up --amount 10 --on element_42
              peekaboo scroll-v2 --direction right --amount 3 --smooth

            DIRECTION:
              up    - Scroll content up (wheel down)
              down  - Scroll content down (wheel up)
              left  - Scroll content left
              right - Scroll content right

            AMOUNT:
              The number of scroll "lines" or "ticks" to perform.
              Each tick is equivalent to one notch on a physical mouse wheel.
        """)

    @Option(help: "Scroll direction: up, down, left, or right")
    var direction: String

    @Option(help: "Number of scroll ticks")
    var amount: Int = 3

    @Option(help: "Element ID to scroll on (from 'see' command)")
    var on: String?

    @Option(help: "Session ID (uses latest if not specified)")
    var session: String?

    @Option(help: "Delay between scroll ticks in milliseconds")
    var delay: Int = 20

    @Flag(help: "Use smooth scrolling with smaller increments")
    var smooth = false

    @Flag(help: "Output in JSON format")
    var jsonOutput = false

    private let services = PeekabooServices.shared

    mutating func run() async throws {
        let startTime = Date()
        Logger.shared.setJsonOutputMode(jsonOutput)

        do {
            // Parse direction
            guard let scrollDirection = ScrollDirection(rawValue: direction.lowercased()) else {
                throw ValidationError("Invalid direction. Use: up, down, left, or right")
            }

            // Determine session ID if element target is specified
            let sessionId: String? = if on != nil {
                session ?? (await services.sessions.getMostRecentSession())
            } else {
                nil
            }

            // Perform scroll using the service
            try await services.automation.scroll(
                direction: scrollDirection,
                amount: amount,
                target: on,
                smooth: smooth,
                delay: delay,
                sessionId: sessionId
            )

            // Calculate total ticks for output
            let totalTicks = smooth ? amount * 3 : amount

            // Determine scroll location for output
            let scrollLocation: CGPoint
            if let elementId = on {
                // Try to get element location from session
                if let activeSessionId = sessionId,
                   let detectionResult = try? await services.sessions.getDetectionResult(sessionId: activeSessionId),
                   let element = detectionResult.elements.findById(elementId) {
                    scrollLocation = CGPoint(
                        x: element.bounds.midX,
                        y: element.bounds.midY
                    )
                } else {
                    // Fallback to zero if element not found (scroll still happened though)
                    scrollLocation = .zero
                }
            } else {
                // Get current mouse position
                scrollLocation = CGEvent(source: nil)?.location ?? .zero
            }

            // Output results
            if jsonOutput {
                let output = ScrollResult(
                    success: true,
                    direction: direction,
                    amount: amount,
                    location: ["x": scrollLocation.x, "y": scrollLocation.y],
                    totalTicks: totalTicks,
                    executionTime: Date().timeIntervalSince(startTime)
                )
                outputSuccessCodable(data: output)
            } else {
                print("✅ Scroll completed")
                print("🎯 Direction: \(direction)")
                print("📊 Amount: \(amount) ticks")
                if on != nil {
                    print("📍 Location: (\(Int(scrollLocation.x)), \(Int(scrollLocation.y)))")
                }
                print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
            }

        } catch {
            handleError(error)
            throw ExitCode.failure
        }
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
                default:
                    errorCode = .INTERNAL_SWIFT_ERROR
                }
            } else if error is ValidationError {
                errorCode = .INVALID_INPUT
            } else if let uiError = error as? UIAutomationError {
                switch uiError {
                case .elementNotFound:
                    errorCode = .ELEMENT_NOT_FOUND
                case .scrollFailed:
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

struct ScrollResult: Codable {
    let success: Bool
    let direction: String
    let amount: Int
    let location: [String: Double]
    let totalTicks: Int
    let executionTime: TimeInterval
}