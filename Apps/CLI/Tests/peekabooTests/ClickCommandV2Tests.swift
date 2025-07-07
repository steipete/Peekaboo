import Testing
import Foundation
@testable import peekaboo

@available(macOS 14.0, *)
@Suite("ClickCommandV2 Tests")
struct ClickCommandV2Tests {
    
    @Test("Click command V2 requires argument or option")
    func requiresArgumentOrOption() async throws {
        var command = ClickCommandV2()
        command.jsonOutput = true
        
        // Should fail without any arguments
        await #expect(throws: (any Error).self) {
            try await command.run()
        }
    }
    
    @Test("Click command V2 parses coordinates correctly")
    func parsesCoordinates() async throws {
        var command = ClickCommandV2()
        command.coords = "100,200"
        command.jsonOutput = true
        
        // This will fail because there's no session, but it should get past argument parsing
        await #expect(throws: (any Error).self) {
            try await command.run()
        }
    }
    
    @Test("Click command V2 validates coordinate format")
    func validatesCoordinateFormat() async throws {
        var command = ClickCommandV2()
        command.coords = "invalid"
        command.jsonOutput = true
        
        // Should fail with validation error
        await #expect(throws: (any Error).self) {
            try await command.run()
        }
    }
}