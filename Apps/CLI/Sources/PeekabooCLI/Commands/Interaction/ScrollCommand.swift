@preconcurrency import ArgumentParser
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

/// Scrolls the mouse wheel in a specified direction.
/// Supports scrolling on specific elements or at the current mouse position.
@available(macOS 14.0, *)
@MainActor
struct ScrollCommand: ErrorHandlingCommand, OutputFormattable {
    static let mainActorConfiguration = CommandConfiguration(
        commandName: "scroll",
        abstract: "Scroll the mouse wheel in any direction",
        discussion: """
            The 'scroll' command simulates mouse wheel scrolling events.
            It can scroll up, down, left, or right by a specified amount.

            EXAMPLES:
              peekaboo scroll --direction down --amount 5
              peekaboo scroll --direction up --amount 10 --on element_42
              peekaboo scroll --direction right --amount 3 --smooth

            DIRECTION:
              up    - Scroll content up (wheel down)
              down  - Scroll content down (wheel up)
              left  - Scroll content left
              right - Scroll content right

            AMOUNT:
              The number of scroll "lines" or "ticks" to perform.
              Each tick is equivalent to one notch on a physical mouse wheel.
        """
    )

    @Option(help: "Scroll direction: up, down, left, or right")
    var direction: String

    @Option(help: "Number of scroll ticks")
    var amount: Int = 3

    @Option(help: "Element ID to scroll on (from 'see' command)")
    var on: String?

    @Option(help: "Session ID (uses latest if not specified)")
    var session: String?

    @Option(help: "Delay between scroll ticks in milliseconds")
    var delay: Int = 2

    @Flag(help: "Use smooth scrolling with smaller increments")
    var smooth = false

    @Option(name: .long, help: "Target application to focus before scrolling")
    var app: String?

    @OptionGroup var focusOptions: FocusCommandOptions

    @OptionGroup var runtimeOptions: CommandRuntimeOptions

    @RuntimeStorage private @RuntimeStorage var runtime: CommandRuntime?

    var outputLogger: Logger {
        self.runtime?.logger ?? Logger.shared
    }

    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        let startTime = Date()
        let services = runtime.services

        do {
            // Parse direction
            guard let scrollDirection = ScrollDirection(rawValue: direction.lowercased()) else {
                throw ArgumentParser.ValidationError("Invalid direction. Use: up, down, left, or right")
            }

            // Determine session ID if element target is specified
            let sessionId: String? = if self.on != nil {
                if let providedSession = session {
                    providedSession
                } else {
                    await services.sessions.getMostRecentSession()
                }
            } else {
                nil
            }

            // Ensure window is focused before scrolling
        try await self.ensureFocused(
            sessionId: sessionId,
            applicationName: self.app,
            options: self.focusOptions,
            services: services
        )

            // Perform scroll using the service
            try await services.automation.scroll(
                direction: scrollDirection,
                amount: self.amount,
                target: self.on,
                smooth: self.smooth,
                delay: self.delay,
                sessionId: sessionId
            )

            // Calculate total ticks for output
            let totalTicks = self.smooth ? self.amount * 3 : self.amount

            // Determine scroll location for output
            let scrollLocation: CGPoint = if let elementId = on {
                // Try to get element location from session
                if let activeSessionId = sessionId,
                   let detectionResult = try? await services.sessions
                       .getDetectionResult(sessionId: activeSessionId),
                       let element = detectionResult.elements.findById(elementId) {
                    CGPoint(
                        x: element.bounds.midX,
                        y: element.bounds.midY
                    )
                } else {
                    // Fallback to zero if element not found (scroll still happened though)
                    .zero
                }
            } else {
                // Get current mouse position
                CGEvent(source: nil)?.location ?? .zero
            }

            // Output results
            if self.jsonOutput {
                let output = ScrollResult(
                    success: true,
                    direction: direction,
                    amount: amount,
                    location: ["x": scrollLocation.x, "y": scrollLocation.y],
                    totalTicks: totalTicks,
                    executionTime: Date().timeIntervalSince(startTime)
                )
                outputSuccessCodable(data: output, logger: self.outputLogger)
            } else {
                print("✅ Scroll completed")
                print("🎯 Direction: \(self.direction)")
                print("📊 Amount: \(self.amount) ticks")
                if self.on != nil {
                    print("📍 Location: (\(Int(scrollLocation.x)), \(Int(scrollLocation.y)))")
                }
                print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
            }

        } catch {
            self.handleError(error)
            throw ExitCode.failure
        }
    }

    // Error handling is provided by ErrorHandlingCommand protocol
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

@MainActor
extension ScrollCommand: AsyncRuntimeCommand {}
