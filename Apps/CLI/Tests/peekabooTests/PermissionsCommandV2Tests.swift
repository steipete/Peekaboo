import Testing
@testable import peekaboo
import Foundation

@Suite
struct PermissionsCommandV2Tests {
    @Test("PermissionsCommandV2 configuration matches original")
    func testCommandConfiguration() {
        // Verify the command has the same configuration as the original
        #expect(PermissionsCommandV2.configuration.commandName == "permissions")
        #expect(PermissionsCommandV2.configuration.abstract == "Check system permissions required for Peekaboo")
        #expect(PermissionsCommandV2.configuration.discussion != nil)
    }
    
    @Test("PermissionsCommandV2 has JSON output flag")
    func testJSONOutputFlag() throws {
        // Create command instance
        let command = PermissionsCommandV2()
        
        // Verify the default value
        #expect(command.jsonOutput == false)
    }
}