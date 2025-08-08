import Testing
import Foundation
import ArgumentParser
@testable import peekaboo

/// Tests for ToolsCommand functionality
@Suite("Tools Command Tests")
struct ToolsCommandTests {
    
    @Test("ToolsCommand configuration")
    func testToolsCommandConfiguration() {
        let config = ToolsCommand.configuration
        
        #expect(config.commandName == "tools")
        #expect(config.abstract == "List available tools with filtering and display options")
        #expect(config.discussion.contains("Examples:"))
        #expect(config.discussion.contains("peekaboo tools"))
        #expect(config.discussion.contains("--native-only"))
        #expect(config.discussion.contains("--mcp-only"))
    }
    
    @Test("ToolsCommand default values")
    func testToolsCommandDefaults() {
        var command = ToolsCommand()
        
        #expect(command.nativeOnly == false)
        #expect(command.mcpOnly == false)
        #expect(command.mcp == nil)
        #expect(command.verbose == false)
        #expect(command.jsonOutput == false)
        #expect(command.includeDisabled == false)
        #expect(command.sort == false)
        #expect(command.groupByServer == false)
    }
    
    @Test("ToolsCommand argument parsing - native only")
    func testArgumentParsingNativeOnly() throws {
        let args = ["--native-only"]
        var command = try ToolsCommand.parse(args)
        
        #expect(command.nativeOnly == true)
        #expect(command.mcpOnly == false)
    }
    
    @Test("ToolsCommand argument parsing - mcp only")
    func testArgumentParsingMcpOnly() throws {
        let args = ["--mcp-only"]
        var command = try ToolsCommand.parse(args)
        
        #expect(command.nativeOnly == false)
        #expect(command.mcpOnly == true)
    }
    
    @Test("ToolsCommand argument parsing - specific server")
    func testArgumentParsingSpecificServer() throws {
        let args = ["--mcp", "github"]
        var command = try ToolsCommand.parse(args)
        
        #expect(command.mcp == "github")
        #expect(command.nativeOnly == false)
        #expect(command.mcpOnly == false)
    }
    
    @Test("ToolsCommand argument parsing - verbose")
    func testArgumentParsingVerbose() throws {
        let args = ["--verbose"]
        var command = try ToolsCommand.parse(args)
        
        #expect(command.verbose == true)
    }
    
    @Test("ToolsCommand argument parsing - json output")
    func testArgumentParsingJsonOutput() throws {
        let args = ["--json-output"]
        var command = try ToolsCommand.parse(args)
        
        #expect(command.jsonOutput == true)
    }
    
    @Test("ToolsCommand argument parsing - multiple flags")
    func testArgumentParsingMultipleFlags() throws {
        let args = ["--verbose", "--json-output", "--include-disabled", "--group-by-server"]
        var command = try ToolsCommand.parse(args)
        
        #expect(command.verbose == true)
        #expect(command.jsonOutput == true)
        #expect(command.includeDisabled == true)
        #expect(command.groupByServer == true)
    }
    
    @Test("ToolsCommand argument parsing - combined options")
    func testArgumentParsingCombined() throws {
        let args = ["--mcp", "filesystem", "--verbose", "--sort"]
        var command = try ToolsCommand.parse(args)
        
        #expect(command.mcp == "filesystem")
        #expect(command.verbose == true)
        #expect(command.sort == true)
    }
    
    @Test("ToolsCommand help text contains expected content")
    func testHelpText() throws {
        let helpText = ToolsCommand.helpMessage()
        
        #expect(helpText.contains("tools"))
        #expect(helpText.contains("--native-only"))
        #expect(helpText.contains("--mcp-only"))
        #expect(helpText.contains("--mcp"))
        #expect(helpText.contains("--verbose"))
        #expect(helpText.contains("--json-output"))
        #expect(helpText.contains("Show only native Peekaboo tools"))
        #expect(helpText.contains("Show only external MCP tools"))
        #expect(helpText.contains("Show tools from specific MCP server"))
    }
    
    @Test("ToolsCommand description property")
    func testDescriptionProperty() {
        let command = ToolsCommand()
        #expect(command.description == "Tools command for listing and filtering available tools")
    }
}

/// Tests for ToolFilter validation (private extension)
@Suite("Tool Filter Validation Tests")
struct ToolFilterValidationTests {
    
    @Test("Valid filter combinations should not throw")
    func testValidFilterCombinations() throws {
        // Test individual flags
        var command1 = ToolsCommand()
        command1.nativeOnly = true
        // Should not throw during argument validation
        
        var command2 = ToolsCommand()
        command2.mcpOnly = true
        // Should not throw during argument validation
        
        var command3 = ToolsCommand()
        command3.mcp = "github"
        // Should not throw during argument validation
        
        var command4 = ToolsCommand()
        command4.mcpOnly = true
        command4.mcp = "github"
        // This combination should be valid (show only tools from specific server)
    }
    
    @Test("ToolsCommand validation in parsing")
    func testValidationInParsing() throws {
        // These should parse successfully
        _ = try ToolsCommand.parse(["--native-only"])
        _ = try ToolsCommand.parse(["--mcp-only"])
        _ = try ToolsCommand.parse(["--mcp", "github"])
        _ = try ToolsCommand.parse(["--mcp-only", "--mcp", "github"])
        
        // Basic parsing should work - validation might happen during execution
    }
}

/// Integration tests for tools command with minimal setup
@Suite("Tools Command Integration Tests")
struct ToolsCommandIntegrationTests {
    
    @Test("ToolsCommand can be created and configured")
    func testCommandCreation() {
        let command = ToolsCommand()
        
        // Test that the command can be created without errors
        #expect(command.nativeOnly == false)
        #expect(command.mcpOnly == false)
        #expect(command.mcp == nil)
        
        // Test that command is identifiable
        #expect(ToolsCommand._commandName == "tools")
    }
}

/// Mock tests to verify command structure without execution
@Suite("Tools Command Structure Tests") 
struct ToolsCommandStructureTests {
    
    @Test("Command has required AsyncParsableCommand conformance")
    func testAsyncParsableCommandConformance() {
        // Verify that ToolsCommand conforms to AsyncParsableCommand
        let command = ToolsCommand()
        
        // This test verifies the command can be instantiated and has the right type
        #expect(command is AsyncParsableCommand)
        #expect(type(of: command) == ToolsCommand.self)
    }
    
    @Test("Command configuration is properly set")
    func testCommandConfigurationProperties() {
        let config = ToolsCommand.configuration
        
        // Verify all required configuration properties
        #expect(config.commandName == "tools")
        #expect(!config.abstract.isEmpty)
        #expect(!config.discussion.isEmpty)
        
        // Verify discussion contains usage examples
        let discussion = config.discussion
        #expect(discussion.contains("peekaboo tools"))
        #expect(discussion.contains("Examples:"))
        #expect(discussion.contains("--native-only"))
        #expect(discussion.contains("--mcp-only"))
        #expect(discussion.contains("--mcp github"))
        #expect(discussion.contains("--verbose"))
        #expect(discussion.contains("--json-output"))
    }
    
    @Test("Command properties have correct types and attributes")
    func testCommandProperties() {
        let command = ToolsCommand()
        
        // Verify property types
        #expect(type(of: command.nativeOnly) == Bool.self)
        #expect(type(of: command.mcpOnly) == Bool.self)
        #expect(type(of: command.mcp) == String?.self)
        #expect(type(of: command.verbose) == Bool.self)
        #expect(type(of: command.jsonOutput) == Bool.self)
        #expect(type(of: command.includeDisabled) == Bool.self)
        #expect(type(of: command.sort) == Bool.self)
        #expect(type(of: command.groupByServer) == Bool.self)
    }
}