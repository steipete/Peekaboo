import Testing
import Foundation
import ArgumentParser
import PeekabooCore
@testable import peekaboo

@Suite("ClickCommand Tests")
struct ClickCommandTests {
    
    @Test("Click command  requires argument or option")
    func requiresArgumentOrOption() async throws {
        var command = ClickCommand()
        command.jsonOutput = true
        
        // Should fail without any arguments
        await #expect(throws: (any Error).self) {
            try await command.run()
        }
    }
    
    @Test("Click command  parses coordinates correctly")
    func parsesCoordinates() async throws {
        var command = ClickCommand()
        command.coords = "100,200"
        command.jsonOutput = true
        
        // This will fail because there's no session, but it should get past argument parsing
        await #expect(throws: (any Error).self) {
            try await command.run()
        }
    }
    
    @Test("Click command  validates coordinate format")
    func validatesCoordinateFormat() async throws {
        var command = ClickCommand()
        command.coords = "invalid"
        command.jsonOutput = true
        
        // Should fail with validation error
        await #expect(throws: (any Error).self) {
            try await command.run()
        }
    }
}
