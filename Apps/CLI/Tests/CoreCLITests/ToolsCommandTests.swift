import Foundation
import Testing
@testable import PeekabooCLI

/// Tests for ToolsCommand functionality
@Suite("Tools Command Tests", .tags(.safe))
struct ToolsCommandTests {
    @Test("ToolsCommand configuration")
    func toolsCommandDescription() {
        let config = ToolsCommand.commandDescription

        #expect(config.commandName == "tools")
        #expect(config.abstract == "List available tools with filtering and display options")
        #expect(config.discussion != nil)
        let discussion = config.discussion ?? ""
        #expect(discussion.contains("Examples:"))
        #expect(discussion.contains("peekaboo tools"))
        #expect(discussion.contains("--native-only"))
        #expect(discussion.contains("--mcp-only"))
    }

    @Test("ToolsCommand default values")
    func toolsCommandDefaults() throws {
        let command = try ToolsCommand.parse([])

        #expect(command.nativeOnly == false)
        #expect(command.mcpOnly == false)
        #expect(command.mcp == nil)
        #expect(command.verbose == false)
        #expect(command.jsonOutput == false)
        #expect(command.includeDisabled == false)
        #expect(command.noSort == false)
        #expect(command.groupByServer == false)
    }

    @Test("ToolsCommand argument parsing - native only")
    func argumentParsingNativeOnly() throws {
        let args = ["--native-only"]
        let command = try ToolsCommand.parse(args)

        #expect(command.nativeOnly == true)
        #expect(command.mcpOnly == false)
    }

    @Test("ToolsCommand argument parsing - mcp only")
    func argumentParsingMcpOnly() throws {
        let args = ["--mcp-only"]
        let command = try ToolsCommand.parse(args)

        #expect(command.nativeOnly == false)
        #expect(command.mcpOnly == true)
    }

    @Test("ToolsCommand argument parsing - specific server")
    func argumentParsingSpecificServer() throws {
        let args = ["--mcp", "github"]
        let command = try ToolsCommand.parse(args)

        #expect(command.mcp == "github")
        #expect(command.nativeOnly == false)
        #expect(command.mcpOnly == false)
    }

    @Test("ToolsCommand argument parsing - verbose")
    func argumentParsingVerbose() throws {
        let args = ["--verbose"]
        let command = try ToolsCommand.parse(args)

        #expect(command.verbose == true)
    }

    @Test("ToolsCommand argument parsing - json output")
    func argumentParsingJsonOutput() throws {
        let args = ["--json"]
        let command = try ToolsCommand.parse(args)

        #expect(command.jsonOutput == true)
    }

    @Test("ToolsCommand argument parsing - multiple flags")
    func argumentParsingMultipleFlags() throws {
        let args = ["--verbose", "--json", "--include-disabled", "--group-by-server"]
        let command = try ToolsCommand.parse(args)

        #expect(command.verbose == true)
        #expect(command.jsonOutput == true)
        #expect(command.includeDisabled == true)
        #expect(command.groupByServer == true)
    }

    @Test("ToolsCommand argument parsing - combined options")
    func argumentParsingCombined() throws {
        let args = ["--mcp", "filesystem", "--verbose", "--no-sort"]
        let command = try ToolsCommand.parse(args)

        #expect(command.mcp == "filesystem")
        #expect(command.verbose == true)
        #expect(command.noSort == true)
    }

    @Test("ToolsCommand description property")
    func descriptionProperty() throws {
        let command = try ToolsCommand.parse([])
        #expect(command.description == "Tools command for listing and filtering available tools")
    }
}

/// Tests for ToolFilter validation (private extension)
@Suite("Tool Filter Validation Tests", .tags(.safe))
struct ToolFilterValidationTests {
    @Test("Valid filter combinations should not throw")
    func validFilterCombinations() throws {
        // Test individual flags
        var command1 = try ToolsCommand.parse([])
        command1.nativeOnly = true
        // Should not throw during argument validation

        var command2 = try ToolsCommand.parse([])
        command2.mcpOnly = true
        // Should not throw during argument validation

        var command3 = try ToolsCommand.parse([])
        command3.mcp = "github"
        // Should not throw during argument validation

        var command4 = try ToolsCommand.parse([])
        command4.mcpOnly = true
        command4.mcp = "github"
        // This combination should be valid (show only tools from specific server)
    }

    @Test("ToolsCommand validation in parsing")
    func validationInParsing() throws {
        // These should parse successfully
        _ = try ToolsCommand.parse(["--native-only"])
        _ = try ToolsCommand.parse(["--mcp-only"])
        _ = try ToolsCommand.parse(["--mcp", "github"])
        _ = try ToolsCommand.parse(["--mcp-only", "--mcp", "github"])

        // Basic parsing should work - validation might happen during execution
    }
}

/// Integration tests for tools command with minimal setup
@Suite("Tools Command Integration Tests", .tags(.safe))
struct ToolsCommandIntegrationTests {
    @Test("ToolsCommand can be created and configured")
    func commandCreation() throws {
        let command = try ToolsCommand.parse([])

        // Test that the command can be created without errors
        #expect(command.nativeOnly == false)
        #expect(command.mcpOnly == false)
        #expect(command.mcp == nil)

        // command name verified in other tests
    }
}

/// Mock tests to verify command structure without execution
@Suite("Tools Command Structure Tests", .tags(.safe))
struct ToolsCommandStructureTests {
    @Test("Command has required AsyncParsableCommand conformance")
    func asyncParsableCommandConformance() throws {
        // Verify that ToolsCommand conforms to AsyncParsableCommand
        let command = try ToolsCommand.parse([])

        // This test verifies the command can be instantiated and has the right type
        #expect(type(of: command) == ToolsCommand.self)
    }

    @Test("Command configuration is properly set")
    func commandConfigurationProperties() {
        let config = ToolsCommand.commandDescription

        // Verify all required configuration properties
        #expect(config.commandName == "tools")
        #expect(!config.abstract.isEmpty)
        #expect(config.discussion != nil)

        // Verify discussion contains usage examples
        let discussion = config.discussion ?? ""
        #expect(discussion.contains("peekaboo tools"))
        #expect(discussion.contains("Examples:"))
        #expect(discussion.contains("--native-only"))
        #expect(discussion.contains("--mcp-only"))
        #expect(discussion.contains("--mcp github"))
        #expect(discussion.contains("--verbose"))
        #expect(discussion.contains("--json"))
    }

    @Test("Command properties have correct types and attributes")
    func commandProperties() throws {
        let command = try ToolsCommand.parse([])

        // Verify property types
        #expect(type(of: command.nativeOnly) == Bool.self)
        #expect(type(of: command.mcpOnly) == Bool.self)
        #expect(type(of: command.mcp) == String?.self)
        #expect(type(of: command.verbose) == Bool.self)
        #expect(type(of: command.jsonOutput) == Bool.self)
        #expect(type(of: command.includeDisabled) == Bool.self)
        #expect(type(of: command.noSort) == Bool.self)
        #expect(type(of: command.groupByServer) == Bool.self)
    }
}
