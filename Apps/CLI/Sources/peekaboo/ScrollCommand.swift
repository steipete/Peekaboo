import ArgumentParser
import AXorcist
import CoreGraphics
import Foundation

/// Scrolls the mouse wheel in a specified direction.
/// Supports scrolling on specific elements or at the current mouse position.
@available(macOS 14.0, *)
struct ScrollCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
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
        """)

    @Option(help: "Scroll direction: up, down, left, or right")
    var direction: ScrollDirection

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

    enum ScrollDirection: String, ExpressibleByArgument {
        case up, down, left, right
    }

    mutating func run() async throws {
        let startTime = Date()

        do {
            // Determine scroll location
            let scrollLocation: CGPoint

            if let elementId = on {
                // Load session and find element
                let sessionCache = try SessionCache(sessionId: session, createIfNeeded: false)
                guard let sessionData = await sessionCache.load() else {
                    throw PeekabooError.sessionNotFound
                }

                guard let element = sessionData.uiMap[elementId] else {
                    throw PeekabooError.elementNotFound
                }

                // Use center of element
                scrollLocation = CGPoint(
                    x: element.frame.midX,
                    y: element.frame.midY)
            } else {
                // Use current mouse position
                scrollLocation = CGEvent(source: nil)?.location ?? CGPoint.zero
            }

            // Perform scroll
            let scrollResult = try await performScroll(
                direction: direction,
                amount: amount,
                at: scrollLocation,
                delayMs: delay,
                smooth: smooth)

            // Output results
            if self.jsonOutput {
                let output = ScrollResult(
                    success: true,
                    direction: direction.rawValue,
                    amount: self.amount,
                    location: ["x": scrollLocation.x, "y": scrollLocation.y],
                    totalTicks: scrollResult.totalTicks,
                    executionTime: Date().timeIntervalSince(startTime))
                outputSuccessCodable(data: output)
            } else {
                print("✅ Scroll completed")
                print("🎯 Direction: \(self.direction.rawValue)")
                print("📊 Amount: \(self.amount) ticks")
                if self.on != nil {
                    print("📍 Location: (\(Int(scrollLocation.x)), \(Int(scrollLocation.y)))")
                }
                print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
            }

        } catch {
            if self.jsonOutput {
                outputError(
                    message: error.localizedDescription,
                    code: .INTERNAL_SWIFT_ERROR)
            } else {
                var localStandardErrorStream = FileHandleTextOutputStream(FileHandle.standardError)
                print("Error: \(error.localizedDescription)", to: &localStandardErrorStream)
            }
            throw ExitCode.failure
        }
    }

    private func performScroll(
        direction: ScrollDirection,
        amount: Int,
        at location: CGPoint,
        delayMs: Int,
        smooth: Bool) async throws -> InternalScrollResult
    {
        // Calculate scroll deltas
        let (deltaX, deltaY) = self.getScrollDeltas(for: direction)

        // Determine tick count and size
        let tickCount = smooth ? amount * 3 : amount
        let tickSize = smooth ? 1 : 3

        var totalTicks = 0

        for _ in 0..<tickCount {
            // Create scroll event
            let scrollEvent = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .line,
                wheelCount: 1,
                wheel1: Int32(deltaY * tickSize),
                wheel2: Int32(deltaX * tickSize),
                wheel3: 0)

            // Set the location for the scroll event
            scrollEvent?.location = location

            // Post the event
            scrollEvent?.post(tap: .cghidEventTap)

            totalTicks += 1

            // Delay between ticks
            if delayMs > 0 {
                try await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
            }
        }

        return InternalScrollResult(totalTicks: totalTicks)
    }

    private func getScrollDeltas(for direction: ScrollDirection) -> (deltaX: Int, deltaY: Int) {
        switch direction {
        case .up:
            (0, 5) // Positive Y scrolls up
        case .down:
            (0, -5) // Negative Y scrolls down
        case .left:
            (5, 0) // Positive X scrolls left
        case .right:
            (-5, 0) // Negative X scrolls right
        }
    }
}

// MARK: - Supporting Types

private struct InternalScrollResult {
    let totalTicks: Int
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
