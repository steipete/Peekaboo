import CoreGraphics
import Foundation
import Testing
@testable import peekaboo

@Suite("SwipeCommandV2 Tests", .serialized)
struct SwipeCommandV2Tests {
    @Test("SwipeCommandV2 parses from and to coordinates")
    func parseCoordinates() throws {
        let command = try SwipeCommandV2.parse([
            "--from-coords", "100,200",
            "--to-coords", "300,400",
        ])
        #expect(command.fromCoords == "100,200")
        #expect(command.toCoords == "300,400")
        #expect(command.duration == 500) // default
        #expect(command.steps == 20) // default
    }

    @Test("SwipeCommandV2 parses all options")
    func parseAllOptions() throws {
        let command = try SwipeCommandV2.parse([
            "--from-coords", "50,100",
            "--to-coords", "250,300",
            "--duration", "1000",
            "--steps", "30",
            "--json-output",
        ])
        #expect(command.fromCoords == "50,100")
        #expect(command.toCoords == "250,300")
        #expect(command.duration == 1000)
        #expect(command.steps == 30)
        #expect(command.jsonOutput)
    }

    @Test("SwipeCommandV2 parses element IDs with session")
    func parseElementIds() throws {
        let command = try SwipeCommandV2.parse([
            "--from", "B1",
            "--to", "T2",
            "--session", "test-session-123",
        ])
        #expect(command.from == "B1")
        #expect(command.to == "T2")
        #expect(command.session == "test-session-123")
    }

    @Test("SwipeCommandV2 parses mixed inputs")
    func parseMixedInputs() throws {
        let command = try SwipeCommandV2.parse([
            "--from", "B1",
            "--to-coords", "500,600",
            "--session", "test-session",
            "--duration", "750",
        ])
        #expect(command.from == "B1")
        #expect(command.toCoords == "500,600")
        #expect(command.session == "test-session")
        #expect(command.duration == 750)
    }

    @Test("SwipeCommandV2 requires both from and to")
    func requiresFromAndTo() throws {
        // Parsing succeeds but validation would fail at runtime
        // Missing both
        let cmd1 = try SwipeCommandV2.parse([])
        #expect(cmd1.from == nil)
        #expect(cmd1.fromCoords == nil)
        #expect(cmd1.to == nil)
        #expect(cmd1.toCoords == nil)

        // Missing to
        let cmd2 = try SwipeCommandV2.parse(["--from-coords", "100,200"])
        #expect(cmd2.fromCoords == "100,200")
        #expect(cmd2.to == nil)
        #expect(cmd2.toCoords == nil)

        // Missing from
        let cmd3 = try SwipeCommandV2.parse(["--to-coords", "300,400"])
        #expect(cmd3.from == nil)
        #expect(cmd3.fromCoords == nil)
        #expect(cmd3.toCoords == "300,400")
    }

    @Test("SwipeCommandV2 right button flag")
    func rightButtonFlag() throws {
        let command = try SwipeCommandV2.parse([
            "--from-coords", "100,200",
            "--to-coords", "300,400",
            "--right-button",
        ])
        #expect(command.rightButton == true)

        let command2 = try SwipeCommandV2.parse([
            "--from-coords", "100,200",
            "--to-coords", "300,400",
        ])
        #expect(command2.rightButton == false)
    }

    @Test("SwipeCommandV2 result structure")
    func swipeResultStructure() {
        let result = SwipeResult(
            success: true,
            fromLocation: ["x": 100.0, "y": 200.0],
            toLocation: ["x": 300.0, "y": 400.0],
            distance: 282.84, // sqrt((300-100)² + (400-200)²)
            duration: 500,
            executionTime: 0.52)

        #expect(result.success == true)
        #expect(result.fromLocation["x"] == 100.0)
        #expect(result.fromLocation["y"] == 200.0)
        #expect(result.toLocation["x"] == 300.0)
        #expect(result.toLocation["y"] == 400.0)
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
        ("", false),
        ("100, 200", true), // with spaces
        (" 100 , 200 ", true), // with extra spaces
    ])
    func validateCoordinateFormat(coords: String, isValid: Bool) {
        // This tests the coordinate parsing logic
        let parts = coords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if isValid {
            #expect(parts.count == 2)
            if parts.count == 2 {
                #expect(Double(parts[0]) != nil)
                #expect(Double(parts[1]) != nil)
            }
        } else {
            #expect(parts
                .count != 2 || (parts.count >= 1 && Double(parts[0]) == nil) ||
                (parts.count >= 2 && Double(parts[1]) == nil))
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
            ((10, 20), (30, 40), 28.284), // Diagonal
        ]

        for testCase in testCases {
            let dx = testCase.to.x - testCase.from.x
            let dy = testCase.to.y - testCase.from.y
            let distance = sqrt(dx * dx + dy * dy)
            #expect(abs(distance - testCase.expectedDistance) < 0.001)
        }
    }
}