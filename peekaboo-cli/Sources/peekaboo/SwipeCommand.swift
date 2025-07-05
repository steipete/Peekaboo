import ArgumentParser
import Foundation
import CoreGraphics
import AXorcist

/// Performs a drag/swipe gesture between two points or elements.
/// Useful for drag-and-drop operations and gesture-based interactions.
@available(macOS 14.0, *)
struct SwipeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swipe",
        abstract: "Drag the mouse from one point to another",
        discussion: """
            The 'swipe' command simulates a drag gesture by pressing the mouse
            button at one location and releasing it at another location.
            
            EXAMPLES:
              peekaboo swipe --from B1 --to B5 --session-id 12345
              peekaboo swipe --from-coords 100,200 --to-coords 300,400
              peekaboo swipe --from T1 --to-coords 500,300 --duration 1000
              
            USAGE:
              You can specify source and destination using either:
              - Element IDs from a previous 'see' command
              - Direct coordinates
              - A mix of both
              
            The swipe includes a configurable duration to control the
            speed of the drag gesture.
        """
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
    
    @Flag(help: "Output in JSON format")
    var jsonOutput = false
    
    mutating func run() async throws {
        let startTime = Date()
        
        do {
            // Validate inputs
            guard (from != nil || fromCoords != nil) && (to != nil || toCoords != nil) else {
                throw ValidationError("Must specify both source (--from or --from-coords) and destination (--to or --to-coords)")
            }
            
            // Get source and destination points
            let sourcePoint = try await getPoint(elementId: from, coords: fromCoords, session: session)
            let destPoint = try await getPoint(elementId: to, coords: toCoords, session: session)
            
            // Perform swipe
            let result = try await performSwipe(
                from: sourcePoint,
                to: destPoint,
                duration: duration,
                steps: steps,
                rightButton: rightButton
            )
            
            // Output results
            if jsonOutput {
                let output = SwipeResult(
                    success: true,
                    fromLocation: ["x": sourcePoint.x, "y": sourcePoint.y],
                    toLocation: ["x": destPoint.x, "y": destPoint.y],
                    distance: result.distance,
                    duration: duration,
                    executionTime: Date().timeIntervalSince(startTime)
                )
                outputSuccessCodable(data: output)
            } else {
                print("✅ Swipe completed")
                print("📍 From: (\(Int(sourcePoint.x)), \(Int(sourcePoint.y)))")
                print("📍 To: (\(Int(destPoint.x)), \(Int(destPoint.y)))")
                print("📏 Distance: \(Int(result.distance)) pixels")
                print("⏱️  Duration: \(duration)ms")
                print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
            }
            
        } catch {
            if jsonOutput {
                outputError(
                    message: error.localizedDescription,
                    code: .INTERNAL_SWIFT_ERROR
                )
            } else {
                var localStandardErrorStream = FileHandleTextOutputStream(FileHandle.standardError)
                print("Error: \(error.localizedDescription)", to: &localStandardErrorStream)
            }
            throw ExitCode.failure
        }
    }
    
    private func getPoint(elementId: String?, coords: String?, session: String?) async throws -> CGPoint {
        if let elementId = elementId {
            // Get point from element
            let sessionCache = SessionCache(sessionId: session)
            guard let sessionData = await sessionCache.load() else {
                throw PeekabooError.sessionNotFound
            }
            
            guard let element = sessionData.uiMap[elementId] else {
                throw PeekabooError.elementNotFound
            }
            
            return CGPoint(x: element.frame.midX, y: element.frame.midY)
            
        } else if let coords = coords {
            // Parse coordinates
            let parts = coords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2,
                  let x = Double(parts[0]),
                  let y = Double(parts[1]) else {
                throw ValidationError("Invalid coordinates format. Use: x,y")
            }
            
            return CGPoint(x: x, y: y)
            
        } else {
            throw ValidationError("No position specified")
        }
    }
    
    private func performSwipe(from: CGPoint,
                            to: CGPoint,
                            duration: Int,
                            steps: Int,
                            rightButton: Bool) async throws -> InternalSwipeResult {
        
        let distance = sqrt(pow(to.x - from.x, 2) + pow(to.y - from.y, 2))
        let stepDelay = max(1, duration / steps)
        
        // Mouse button type
        let buttonType: CGMouseButton = rightButton ? .right : .left
        let downEventType: CGEventType = rightButton ? .rightMouseDown : .leftMouseDown
        let upEventType: CGEventType = rightButton ? .rightMouseUp : .leftMouseUp
        let dragEventType: CGEventType = rightButton ? .rightMouseDragged : .leftMouseDragged
        
        // Press mouse button at start location
        let mouseDown = CGEvent(
            mouseEventSource: nil,
            mouseType: downEventType,
            mouseCursorPosition: from,
            mouseButton: buttonType
        )
        mouseDown?.post(tap: .cghidEventTap)
        
        // Small initial delay
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Move through intermediate points
        for i in 1...steps {
            let progress = Double(i) / Double(steps)
            let intermediatePoint = CGPoint(
                x: from.x + (to.x - from.x) * progress,
                y: from.y + (to.y - from.y) * progress
            )
            
            let dragEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: dragEventType,
                mouseCursorPosition: intermediatePoint,
                mouseButton: buttonType
            )
            dragEvent?.post(tap: .cghidEventTap)
            
            // Delay between movements
            if stepDelay > 0 {
                try await Task.sleep(nanoseconds: UInt64(stepDelay) * 1_000_000)
            }
        }
        
        // Release mouse button at end location
        let mouseUp = CGEvent(
            mouseEventSource: nil,
            mouseType: upEventType,
            mouseCursorPosition: to,
            mouseButton: buttonType
        )
        mouseUp?.post(tap: .cghidEventTap)
        
        return InternalSwipeResult(distance: distance)
    }
}

// MARK: - Supporting Types

private struct InternalSwipeResult {
    let distance: Double
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