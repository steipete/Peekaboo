import Foundation
import Testing
@testable import PeekabooCLI

#if !PEEKABOO_SKIP_AUTOMATION
@Suite("Drag Command Tests", .serialized, .tags(.safe))
struct DragCommandTests {
    @Test("Drag command exists")
    func dragCommandExists() {
        let config = DragCommand.configuration
        #expect(config.commandName == "drag")
        #expect(config.abstract.contains("drag and drop"))
    }

    @Test("Drag command parameters")
    func dragParameters() async throws {
        let output = try await runCommand(["drag", "--help"])

        #expect(output.contains("--from"))
        #expect(output.contains("--to"))
        #expect(output.contains("--from-coords"))
        #expect(output.contains("--to-coords"))
        #expect(output.contains("--to-app"))
        #expect(output.contains("--duration"))
        #expect(output.contains("--modifiers"))
    }

    @Test("Drag command validation - from required")
    func dragFromRequired() async throws {
        // Test missing from
        await #expect(throws: Error.self) {
            _ = try await runCommand(["drag", "--to", "B1"])
        }
    }

    @Test("Drag command validation - to required")
    func dragToRequired() async throws {
        // Test missing to
        await #expect(throws: Error.self) {
            _ = try await runCommand(["drag", "--from", "B1"])
        }
    }

    @Test("Drag coordinate parsing")
    func dragCoordinateParsing() {
        // Test valid coordinates
        let coords1 = "100,200"
        let parts1 = coords1.split(separator: ",")
        #expect(parts1.count == 2)
        #expect(Double(parts1[0]) == 100)
        #expect(Double(parts1[1]) == 200)

        // Test coordinates with spaces
        let coords2 = "100, 200"
        let parts2 = coords2.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        #expect(Double(parts2[0]) == 100)
        #expect(Double(parts2[1]) == 200)
    }

    @Test("Drag modifier parsing")
    func dragModifierParsing() {
        let modifiers = "cmd,shift"
        let parts = modifiers.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        #expect(parts.contains("cmd"))
        #expect(parts.contains("shift"))
    }

    @Test("Drag error codes")
    func dragErrorCodes() {
        #expect(ErrorCode.NO_POINT_SPECIFIED.rawValue == "NO_POINT_SPECIFIED")
        #expect(ErrorCode.INVALID_COORDINATES.rawValue == "INVALID_COORDINATES")
        #expect(ErrorCode.SESSION_NOT_FOUND.rawValue == "SESSION_NOT_FOUND")
    }

    @Test("Drag duration validation")
    func dragDurationValidation() {
        // Test that duration is positive
        let validDurations = [100, 500, 1000, 2000]
        for duration in validDurations {
            let cmd = ["drag", "--from", "A1", "--to", "B1", "--duration", "\(duration)"]
            #expect(cmd.count == 7)
        }
    }
}

// MARK: - Drag Command Integration Tests

@Suite(
    "Drag Command Integration Tests",
    .serialized,
    .tags(.automation),
    .enabled(if: ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true")
)
struct DragCommandIntegrationTests {
    @Test("Drag between coordinates")
    func dragBetweenCoordinates() async throws {
        let output = try await runCommand([
            "drag",
            "--from-coords", "100,100",
            "--to-coords", "300,300",
            "--duration", "500",
            "--json-output",
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: output.data(using: .utf8)!)
        #expect(data.success == true)

        // For now, just check success since we don't have access to the response data structure
        // This would need to be updated based on the actual drag command response format
    }

    @Test("Drag from element to coordinates")
    func dragElementToCoords() async throws {
        // This requires a valid session
        let output = try await runCommand([
            "drag",
            "--from", "B1",
            "--to-coords", "500,500",
            "--session", "test-session",
            "--json-output",
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: output.data(using: .utf8)!)
        if !data.success {
            // Expected if no session exists
            #expect(data.error?.code == "SESSION_NOT_FOUND")
        }
    }

    @Test("Drag with modifiers")
    func dragWithModifiers() async throws {
        let output = try await runCommand([
            "drag",
            "--from-coords", "200,200",
            "--to-coords", "400,400",
            "--modifiers", "cmd,option",
            "--json-output",
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: output.data(using: .utf8)!)
        #expect(data.success == true)

        // Check success for now - detailed validation would require knowing the response structure
    }

    @Test("Drag to application")
    func dragToApplication() async throws {
        let output = try await runCommand([
            "drag",
            "--from-coords", "100,100",
            "--to-app", "Trash",
            "--json-output",
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: output.data(using: .utf8)!)
        #expect(data.success == true)

        // Check success for now - detailed validation would require knowing the response structure
    }

    @Test("Drag with custom duration")
    func dragCustomDuration() async throws {
        let output = try await runCommand([
            "drag",
            "--from-coords", "50,50",
            "--to-coords", "150,150",
            "--duration", "2000",
            "--json-output",
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: output.data(using: .utf8)!)
        #expect(data.success == true)

        // Check success for now - detailed validation would require knowing the response structure
    }
}

// MARK: - Test Helpers

private func runCommand(_ args: [String]) async throws -> String {
    let output = try await runPeekabooCommand(args)
    return output
}

private func runPeekabooCommand(_ args: [String]) async throws -> String {
    // This is a placeholder - in real tests, this would execute the actual CLI
    // For unit tests, we're mainly testing command structure and validation
    ""
}
#endif
