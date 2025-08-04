import Testing
import Foundation
import ArgumentParser
@testable import peekaboo

/// Tests for MCP client management commands
@Suite("MCP Client Command Tests")
struct MCPClientCommandTests {
    
    @Test("MCPCommand configuration includes all subcommands")
    func testMCPCommandConfiguration() {
        let config = MCPCommand.configuration
        
        #expect(config.commandName == "mcp")
        #expect(config.abstract == "Model Context Protocol server and client operations")
        #expect(config.discussion?.contains("EXAMPLES:") == true)
        
        // Verify all subcommands are present
        #expect(config.subcommands.count == 10) // Serve, List, Add, Remove, Test, Info, Enable, Disable, Call, Inspect
        
        let subcommandNames = config.subcommands.map { $0._commandName }
        #expect(subcommandNames.contains("serve"))
        #expect(subcommandNames.contains("list"))
        #expect(subcommandNames.contains("add"))
        #expect(subcommandNames.contains("remove"))
        #expect(subcommandNames.contains("test"))
        #expect(subcommandNames.contains("info"))
        #expect(subcommandNames.contains("enable"))
        #expect(subcommandNames.contains("disable"))
        #expect(subcommandNames.contains("call"))
        #expect(subcommandNames.contains("inspect"))
    }
}

/// Tests for MCP List command
@Suite("MCP List Command Tests")
struct MCPListCommandTests {
    
    @Test("List command configuration")
    func testListCommandConfiguration() {
        let config = MCPCommand.List.configuration
        
        #expect(config.abstract == "List configured MCP servers with health status")
        #expect(config.discussion?.contains("EXAMPLE OUTPUT:") == true)
        #expect(config.discussion?.contains("Checking MCP server health...") == true)
        #expect(config.discussion?.contains("✓ Connected") == true)
        #expect(config.discussion?.contains("✗ Failed to connect") == true)
    }
    
    @Test("List command default values")
    func testListCommandDefaults() {
        let command = MCPCommand.List()
        
        #expect(command.jsonOutput == false)
        #expect(command.skipHealthCheck == false)
    }
    
    @Test("List command argument parsing")
    func testListCommandArgumentParsing() throws {
        let args = ["mcp", "list", "--json-output", "--skip-health-check"]
        let parsed = try MCPCommand.parseAsRoot(args) as! MCPCommand
        
        // We can't easily access the subcommand from the parsed result
        // but we can verify the parsing succeeds
    }
    
    @Test("List command help text")
    func testListCommandHelpText() {
        let helpText = MCPCommand.List.helpMessage()
        
        #expect(helpText.contains("list"))
        #expect(helpText.contains("--json-output"))
        #expect(helpText.contains("--skip-health-check"))
        #expect(helpText.contains("Output in JSON format"))
        #expect(helpText.contains("Skip health checks"))
    }
}

/// Tests for MCP Add command
@Suite("MCP Add Command Tests")
struct MCPAddCommandTests {
    
    @Test("Add command configuration")
    func testAddCommandConfiguration() {
        let config = MCPCommand.Add.configuration
        
        #expect(config.commandName == "add")
        #expect(config.abstract == "Add a new external MCP server")
        #expect(config.discussion?.contains("EXAMPLES:") == true)
        #expect(config.discussion?.contains("npx -y @modelcontextprotocol/server-github") == true)
        #expect(config.discussion?.contains("npx -y @modelcontextprotocol/server-filesystem") == true)
    }
    
    @Test("Add command default values")
    func testAddCommandDefaults() {
        var command = MCPCommand.Add()
        command.name = "test-server"
        
        #expect(command.env.isEmpty)
        #expect(command.timeout == 10.0)
        #expect(command.transport == "stdio")
        #expect(command.description == nil)
        #expect(command.disabled == false)
        #expect(command.command.isEmpty)
    }
    
    @Test("Add command help text contains expected options")
    func testAddCommandHelpText() {
        let helpText = MCPCommand.Add.helpMessage()
        
        #expect(helpText.contains("add"))
        #expect(helpText.contains("Name for the MCP server"))
        #expect(helpText.contains("Environment variables"))
        #expect(helpText.contains("Connection timeout"))
        #expect(helpText.contains("Transport type"))
        #expect(helpText.contains("Description of the server"))
        #expect(helpText.contains("Disable the server after adding"))
        #expect(helpText.contains("Command and arguments"))
    }
}

/// Tests for MCP Remove command
@Suite("MCP Remove Command Tests")
struct MCPRemoveCommandTests {
    
    @Test("Remove command configuration")
    func testRemoveCommandConfiguration() {
        let config = MCPCommand.Remove.configuration
        
        #expect(config.commandName == "remove")
        #expect(config.abstract == "Remove an external MCP server")
        #expect(config.discussion == "Remove a configured MCP server and disconnect from it.")
    }
    
    @Test("Remove command default values")
    func testRemoveCommandDefaults() {
        var command = MCPCommand.Remove()
        command.name = "test-server"
        
        #expect(command.force == false)
    }
    
    @Test("Remove command help text")
    func testRemoveCommandHelpText() {
        let helpText = MCPCommand.Remove.helpMessage()
        
        #expect(helpText.contains("remove"))
        #expect(helpText.contains("Name of the MCP server to remove"))
        #expect(helpText.contains("Skip confirmation prompt"))
        #expect(helpText.contains("--force"))
    }
}

/// Tests for MCP Test command
@Suite("MCP Test Command Tests")
struct MCPTestCommandTests {
    
    @Test("Test command configuration")
    func testTestCommandConfiguration() {
        let config = MCPCommand.Test.configuration
        
        #expect(config.commandName == "test")
        #expect(config.abstract == "Test connection to an MCP server")
        #expect(config.discussion == "Test connectivity and list available tools from an MCP server.")
    }
    
    @Test("Test command default values")
    func testTestCommandDefaults() {
        var command = MCPCommand.Test()
        command.name = "test-server"
        
        #expect(command.timeout == 10.0)
        #expect(command.showTools == false)
    }
    
    @Test("Test command help text")
    func testTestCommandHelpText() {
        let helpText = MCPCommand.Test.helpMessage()
        
        #expect(helpText.contains("test"))
        #expect(helpText.contains("Name of the MCP server to test"))
        #expect(helpText.contains("Connection timeout"))
        #expect(helpText.contains("Show available tools"))
        #expect(helpText.contains("--show-tools"))
    }
}

/// Tests for MCP Info command
@Suite("MCP Info Command Tests")
struct MCPInfoCommandTests {
    
    @Test("Info command configuration")
    func testInfoCommandConfiguration() {
        let config = MCPCommand.Info.configuration
        
        #expect(config.commandName == "info")
        #expect(config.abstract == "Show detailed information about an MCP server")
        #expect(config.discussion == "Display comprehensive information about a configured MCP server.")
    }
    
    @Test("Info command default values")
    func testInfoCommandDefaults() {
        var command = MCPCommand.Info()
        command.name = "test-server"
        
        #expect(command.jsonOutput == false)
    }
    
    @Test("Info command help text")
    func testInfoCommandHelpText() {
        let helpText = MCPCommand.Info.helpMessage()
        
        #expect(helpText.contains("info"))
        #expect(helpText.contains("Name of the MCP server"))
        #expect(helpText.contains("Output in JSON format"))
        #expect(helpText.contains("--json-output"))
    }
}

/// Tests for MCP Enable command
@Suite("MCP Enable Command Tests")
struct MCPEnableCommandTests {
    
    @Test("Enable command configuration")
    func testEnableCommandConfiguration() {
        let config = MCPCommand.Enable.configuration
        
        #expect(config.commandName == "enable")
        #expect(config.abstract == "Enable a disabled MCP server")
        #expect(config.discussion == "Enable a previously disabled MCP server and attempt to connect.")
    }
    
    @Test("Enable command default values")
    func testEnableCommandDefaults() {
        var command = MCPCommand.Enable()
        command.name = "test-server"
        
        // No additional properties to test defaults for
        #expect(command.name == "test-server")
    }
    
    @Test("Enable command help text")
    func testEnableCommandHelpText() {
        let helpText = MCPCommand.Enable.helpMessage()
        
        #expect(helpText.contains("enable"))
        #expect(helpText.contains("Name of the MCP server to enable"))
    }
}

/// Tests for MCP Disable command
@Suite("MCP Disable Command Tests")
struct MCPDisableCommandTests {
    
    @Test("Disable command configuration")
    func testDisableCommandConfiguration() {
        let config = MCPCommand.Disable.configuration
        
        #expect(config.commandName == "disable")
        #expect(config.abstract == "Disable an MCP server")
        #expect(config.discussion == "Disable an MCP server without removing its configuration.")
    }
    
    @Test("Disable command default values")
    func testDisableCommandDefaults() {
        var command = MCPCommand.Disable()
        command.name = "test-server"
        
        // No additional properties to test defaults for
        #expect(command.name == "test-server")
    }
    
    @Test("Disable command help text")
    func testDisableCommandHelpText() {
        let helpText = MCPCommand.Disable.helpMessage()
        
        #expect(helpText.contains("disable"))
        #expect(helpText.contains("Name of the MCP server to disable"))
    }
}

/// Tests for argument parsing edge cases
@Suite("MCP Command Parsing Tests")
struct MCPCommandParsingTests {
    
    @Test("Parsing MCP list with flags")
    func testParsingListWithFlags() throws {
        let args = ["mcp", "list", "--json-output"]
        let parsed = try MCPCommand.parseAsRoot(args)
        
        // Verify it parses without throwing
        #expect(parsed is MCPCommand)
    }
    
    @Test("Parsing MCP add with complex arguments")
    func testParsingAddWithComplexArguments() throws {
        let args = [
            "mcp", "add", "github",
            "-e", "API_KEY=test123",
            "-e", "ANOTHER_VAR=value",
            "--timeout", "15.0",
            "--transport", "stdio",
            "--description", "GitHub server",
            "--",
            "npx", "-y", "@modelcontextprotocol/server-github"
        ]
        
        let parsed = try MCPCommand.parseAsRoot(args)
        
        // Verify it parses without throwing
        #expect(parsed is MCPCommand)
    }
    
    @Test("Parsing MCP remove with force flag")
    func testParsingRemoveWithForce() throws {
        let args = ["mcp", "remove", "test-server", "--force"]
        let parsed = try MCPCommand.parseAsRoot(args)
        
        // Verify it parses without throwing
        #expect(parsed is MCPCommand)
    }
    
    @Test("Parsing MCP test with options")
    func testParsingTestWithOptions() throws {
        let args = ["mcp", "test", "github", "--timeout", "5.0", "--show-tools"]
        let parsed = try MCPCommand.parseAsRoot(args)
        
        // Verify it parses without throwing
        #expect(parsed is MCPCommand)
    }
    
    @Test("Parsing MCP info with JSON output")
    func testParsingInfoWithJson() throws {
        let args = ["mcp", "info", "github", "--json-output"]
        let parsed = try MCPCommand.parseAsRoot(args)
        
        // Verify it parses without throwing
        #expect(parsed is MCPCommand)
    }
    
    @Test("Invalid MCP subcommand should fail parsing")
    func testInvalidSubcommand() {
        let args = ["mcp", "invalid-subcommand"]
        
        #expect(throws: (any Error).self) {
            try MCPCommand.parseAsRoot(args)
        }
    }
}

/// Tests for command structure and relationships
@Suite("MCP Command Structure Tests")
struct MCPCommandStructureTests {
    
    @Test("All MCP subcommands are AsyncParsableCommand")
    func testSubcommandTypes() {
        // Verify that all subcommands conform to AsyncParsableCommand
        #expect(MCPCommand.Serve() is AsyncParsableCommand)
        #expect(MCPCommand.List() is AsyncParsableCommand)
        #expect(MCPCommand.Add() is AsyncParsableCommand)
        #expect(MCPCommand.Remove() is AsyncParsableCommand)
        #expect(MCPCommand.Test() is AsyncParsableCommand)
        #expect(MCPCommand.Info() is AsyncParsableCommand)
        #expect(MCPCommand.Enable() is AsyncParsableCommand)
        #expect(MCPCommand.Disable() is AsyncParsableCommand)
        #expect(MCPCommand.Call() is AsyncParsableCommand)
        #expect(MCPCommand.Inspect() is AsyncParsableCommand)
    }
    
    @Test("Subcommand configurations are properly set")
    func testSubcommandConfigurations() {
        // Test that each subcommand has proper configuration
        #expect(MCPCommand.Serve.configuration.abstract.contains("MCP server"))
        #expect(MCPCommand.List.configuration.abstract.contains("List configured"))
        #expect(MCPCommand.Add.configuration.abstract.contains("Add a new"))
        #expect(MCPCommand.Remove.configuration.abstract.contains("Remove an"))
        #expect(MCPCommand.Test.configuration.abstract.contains("Test connection"))
        #expect(MCPCommand.Info.configuration.abstract.contains("Show detailed"))
        #expect(MCPCommand.Enable.configuration.abstract.contains("Enable a disabled"))
        #expect(MCPCommand.Disable.configuration.abstract.contains("Disable an"))
        #expect(MCPCommand.Call.configuration.abstract.contains("Call a tool"))
        #expect(MCPCommand.Inspect.configuration.abstract.contains("Debug MCP"))
    }
}