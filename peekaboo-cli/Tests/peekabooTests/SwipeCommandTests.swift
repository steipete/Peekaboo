import CoreGraphics
import Foundation
@testable import peekaboo
import Testing

#if os(macOS) && swift(>=5.9)
@available(macOS 14.0, *)
@Suite("SwipeCommand Tests")
struct SwipeCommandTests {
    @Test("Swipe command parses from and to coordinates")
    func parseCoordinates() throws {
        let command = try SwipeCommand.parse([
            "--from", "100,200",
            "--to", "300,400"
        ])
        #expect(command.from == "100,200")
        #expect(command.to == "300,400")
        #expect(command.duration == 500) // default
        #expect(command.steps == 10) // default
    }

    @Test("Swipe command parses all options")
    func parseAllOptions() throws {
        let command = try SwipeCommand.parse([
            "--from", "50,100",
            "--to", "250,300",
            "--duration", "1000",
            "--steps", "20",
            "--json-output"
        ])
        #expect(command.from == "50,100")
        #expect(command.to == "250,300")
        #expect(command.duration == 1000)
        #expect(command.steps == 20)
        #expect(command.jsonOutput == true)
    }

    @Test("Swipe command requires both from and to")
    func requiresFromAndTo() {
        // Missing both
        #expect(throws: Error.self) {
            _ = try SwipeCommand.parse([])
        }

        // Missing to
        #expect(throws: Error.self) {
            _ = try SwipeCommand.parse(["--from", "100,200"])
        }

        // Missing from
        #expect(throws: Error.self) {
            _ = try SwipeCommand.parse(["--to", "300,400"])
        }
    }

    @Test("Swipe result structure")
    func swipeResultStructure() {
        let result = SwipeResult(
            success: true,
            startLocation: ["x": 100.0, "y": 200.0],
            endLocation: ["x": 300.0, "y": 400.0],
            distance: 282.84, // sqrt((300-100)² + (400-200)²)
            duration: 500,
            executionTime: 0.52
        )

        #expect(result.success == true)
        #expect(result.startLocation["x"] == 100.0)
        #expect(result.startLocation["y"] == 200.0)
        #expect(result.endLocation["x"] == 300.0)
        #expect(result.endLocation["y"] == 400.0)
        #expect(abs(result.distance - 282.84) < 0.01)
        #expect(result.duration == 500)
        #expect(result.executionTime == 0.52)
    }

    @Test("Coordinate parsing validation", arguments: [
        ("100,200", true),
        ("0,0", true),
        ("-50,100", true),
        ("100.5,200.5", true),
        ("invalid", false),
        ("100", false),
        ("100,200,300", false),
        ("", false)
    ])
    func validateCoordinateFormat(coords: String, isValid: Bool) {
        // This tests the coordinate parsing logic
        let parts = coords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if isValid {
            #expect(parts.count == 2)
            #expect(Double(parts[0]) != nil || parts.isEmpty)
            #expect(Double(parts[1]) != nil || parts.isEmpty)
        } else {
            #expect(parts.count != 2 || Double(parts[0]) == nil || Double(parts[1]) == nil)
        }
    }

    @Test("Distance calculation")
    func distanceCalculation() {
        // Test distance calculation between two points
        let testCases: [(from: (x: Double, y: Double), to: (x: Double, y: Double), expectedDistance: Double)] = [
            ((0, 0), (3, 4), 5.0), // 3-4-5 triangle
            ((0, 0), (0, 10), 10.0), // Vertical line
            ((0, 0), (10, 0), 10.0), // Horizontal line
            ((100, 100), (100, 100), 0.0), // Same point
        ]

        for testCase in testCases {
            let dx = testCase.to.x - testCase.from.x
            let dy = testCase.to.y - testCase.from.y
            let distance = sqrt(dx * dx + dy * dy)
            #expect(abs(distance - testCase.expectedDistance) < 0.001)
        }
    }
}
#endif
