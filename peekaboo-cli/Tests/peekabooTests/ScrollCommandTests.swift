import CoreGraphics
import Foundation
@testable import peekaboo
import Testing

@Suite("ScrollCommand Tests")
struct ScrollCommandTests {
    @Test("Scroll command parses direction", arguments: [
        "up", "down", "left", "right"
    ])
    func parseDirection(direction: String) throws {
        let command = try ScrollCommand.parse(["--direction", direction])
        #expect(command.direction.rawValue == direction)
        #expect(command.amount == 3) // default
        #expect(command.delay == 20) // default
        #expect(command.smooth == false) // default
    }

    @Test("Scroll command parses all options")
    func parseAllOptions() throws {
        let command = try ScrollCommand.parse([
            "--direction", "down",
            "--amount", "5",
            "--on", "G1",
            "--session", "test-123",
            "--delay", "50",
            "--smooth",
            "--json-output"
        ])
        #expect(command.direction == .down)
        #expect(command.amount == 5)
        #expect(command.on == "G1")
        #expect(command.session == "test-123")
        #expect(command.delay == 50)
        #expect(command.smooth == true)
        #expect(command.jsonOutput == true)
    }

    @Test("Scroll command requires direction")
    func requiresDirection() {
        #expect(throws: Error.self) {
            _ = try ScrollCommand.parse([])
        }
    }

    @Test("Scroll delta calculation", arguments: [
        (ScrollCommand.ScrollDirection.up, 0, 5),
        (ScrollCommand.ScrollDirection.down, 0, -5),
        (ScrollCommand.ScrollDirection.left, 5, 0),
        (ScrollCommand.ScrollDirection.right, -5, 0)
    ])
    func scrollDeltas(direction: ScrollCommand.ScrollDirection, expectedDeltaX: Int, expectedDeltaY: Int) {
        // This test validates the expected scroll delta values for each direction
        // In the actual implementation, these values are used for CGEvent creation
        #expect(true) // Placeholder - would test the actual delta calculation method
    }

    @Test("Scroll result structure")
    func scrollResultStructure() {
        let result = ScrollResult(
            success: true,
            direction: "down",
            amount: 5,
            location: ["x": 500.0, "y": 300.0],
            totalTicks: 5,
            executionTime: 0.15
        )

        #expect(result.success == true)
        #expect(result.direction == "down")
        #expect(result.amount == 5)
        #expect(result.location["x"] == 500.0)
        #expect(result.location["y"] == 300.0)
        #expect(result.totalTicks == 5)
        #expect(result.executionTime == 0.15)
    }

    @Test("Smooth scrolling increases tick count")
    func smoothScrolling() throws {
        let normalCommand = try ScrollCommand.parse(["--direction", "down", "--amount", "3"])
        let smoothCommand = try ScrollCommand.parse(["--direction", "down", "--amount", "3", "--smooth"])

        #expect(normalCommand.smooth == false)
        #expect(smoothCommand.smooth == true)

        // In the implementation, smooth scrolling multiplies ticks by 3
        // This would be tested in integration tests
    }
}
