import Testing
@testable import peekaboo
import Foundation

@Suite
struct PermissionsCommandTests {
    @Test("PermissionsCommand configuration matches original")
    func testCommandConfiguration() {
        // Verify the command has the same configuration as the original
        #expect(PermissionsCommand.configuration.commandName == "permissions")
        #expect(PermissionsCommand.configuration.abstract == "Check system permissions required for Peekaboo")
        #expect(!PermissionsCommand.configuration.discussion.isEmpty)
    }
    
    @Test("PermissionsCommand has JSON output flag")
    func testJSONOutputFlag() throws {
        // Create command instance
        let command = PermissionsCommand()
        
        // Verify the default value
        #expect(command.jsonOutput == false)
    }
}