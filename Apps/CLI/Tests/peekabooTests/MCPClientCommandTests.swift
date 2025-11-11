import Foundation
import Testing
@testable import PeekabooCLI

/// Tests for MCP client management commands
@Suite("MCP Client Command Tests")
struct MCPClientCommandTests {
    @Test("MCPCommand configuration includes all subcommands")
    func mCPCommandDescription() {
        let config = MCPCommand.commandDescription

        #expect(config.commandName == "mcp")
        #expect(config.abstract == "Model Context Protocol server and client operations")
        #expect(config.discussion.contains("EXAMPLES:"))

        // Verify all subcommands are present
        #expect(config.subcommands.count == 10) // Serve, List, Add, Remove, Test, Info, Enable, Disable, Call, Inspect

        let subcommandNames = config.subcommands.map { $0.commandDescription.commandName ?? String(describing: $0) }
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
    func listCommandDescription() {
        let config = MCPCommand.List.commandDescription

        #expect(config.abstract == "List configured MCP servers with health status")
        #expect(config.discussion.contains("EXAMPLE OUTPUT:"))
        #expect(config.discussion.contains("Checking MCP server health..."))
        #expect(config.discussion.contains("✓ Connected"))
        #expect(config.discussion.contains("✗ Failed to connect"))
    }

    @Test("List command default values")
    func listCommandDefaults() {
        let command = MCPCommand.List()

        #expect(command.jsonOutput == false)
        #expect(command.skipHealthCheck == false)
    }

    @Test("List command argument parsing")
    func listCommandArgumentParsing() throws {
        _ = try MCPCommand.parse(["list", "--json-output", "--skip-health-check"])

        // We can't easily access the subcommand from the parsed result
        // but we can verify the parsing succeeds
    }

    @Test("List command help text")
    func listCommandHelpText() {
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
    func addCommandDescription() {
        let config = MCPCommand.Add.commandDescription

        #expect(config.commandName == "add")
        #expect(config.abstract == "Add a new external MCP server")
        #expect(config.discussion.contains("EXAMPLES:"))
        #expect(config.discussion.contains("npx -y @modelcontextprotocol/server-github"))
        #expect(config.discussion.contains("npx -y @modelcontextprotocol/server-filesystem"))
    }

    @Test("Add command default values")
    func addCommandDefaults() {
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
    func addCommandHelpText() {
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
    func removeCommandDescription() {
        let config = MCPCommand.Remove.commandDescription

        #expect(config.commandName == "remove")
        #expect(config.abstract == "Remove an external MCP server")
        #expect(config.discussion == "Remove a configured MCP server and disconnect from it.")
    }

    @Test("Remove command default values")
    func removeCommandDefaults() {
        var command = MCPCommand.Remove()
        command.name = "test-server"

        #expect(command.force == false)
    }

    @Test("Remove command help text")
    func removeCommandHelpText() {
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
    func commandConfiguration() {
        let config = MCPCommand.Test.commandDescription

        #expect(config.commandName == "test")
        #expect(config.abstract == "Test connection to an MCP server")
        #expect(config.discussion == "Test connectivity and list available tools from an MCP server.")
    }

    @Test("Test command default values")
    func commandDefaults() {
        var command = MCPCommand.Test()
        command.name = "test-server"

        #expect(command.timeout == 10.0)
        #expect(command.showTools == false)
    }

    @Test("Test command help text")
    func commandHelpText() {
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
    func infoCommandDescription() {
        let config = MCPCommand.Info.commandDescription

        #expect(config.commandName == "info")
        #expect(config.abstract == "Show detailed information about an MCP server")
        #expect(config.discussion == "Display comprehensive information about a configured MCP server.")
    }

    @Test("Info command default values")
    func infoCommandDefaults() {
        var command = MCPCommand.Info()
        command.name = "test-server"

        #expect(command.jsonOutput == false)
    }

    @Test("Info command help text")
    func infoCommandHelpText() {
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
    func enableCommandDescription() {
        let config = MCPCommand.Enable.commandDescription

        #expect(config.commandName == "enable")
        #expect(config.abstract == "Enable a disabled MCP server")
        #expect(config.discussion == "Enable a previously disabled MCP server and attempt to connect.")
    }

    @Test("Enable command default values")
    func enableCommandDefaults() {
        var command = MCPCommand.Enable()
        command.name = "test-server"

        // No additional properties to test defaults for
        #expect(command.name == "test-server")
    }

    @Test("Enable command help text")
    func enableCommandHelpText() {
        let helpText = MCPCommand.Enable.helpMessage()

        #expect(helpText.contains("enable"))
        #expect(helpText.contains("Name of the MCP server to enable"))
    }
}

/// Tests for MCP Disable command
@Suite("MCP Disable Command Tests")
struct MCPDisableCommandTests {
    @Test("Disable command configuration")
    func disableCommandDescription() {
        let config = MCPCommand.Disable.commandDescription

        #expect(config.commandName == "disable")
        #expect(config.abstract == "Disable an MCP server")
        #expect(config.discussion == "Disable an MCP server without removing its configuration.")
    }

    @Test("Disable command default values")
    func disableCommandDefaults() {
        var command = MCPCommand.Disable()
        command.name = "test-server"

        // No additional properties to test defaults for
        #expect(command.name == "test-server")
    }

    @Test("Disable command help text")
    func disableCommandHelpText() {
        let helpText = MCPCommand.Disable.helpMessage()

        #expect(helpText.contains("disable"))
        #expect(helpText.contains("Name of the MCP server to disable"))
    }
}

/// Tests for argument parsing edge cases
@Suite("MCP Command Parsing Tests")
struct MCPCommandParsingTests {
    @Test("Parsing MCP list with flags")
    func parsingListWithFlags() throws {
        let args = ["--json-output"]
        let command = try MCPCommand.List.parse(args)
        #expect(command.jsonOutput == true)
    }

    @Test("Parsing MCP add with complex arguments")
    func parsingAddWithComplexArguments() throws {
        let args = [
            "github",
            "-e", "API_KEY=test123",
            "-e", "ANOTHER_VAR=value",
            "--timeout", "15.0",
            "--transport", "stdio",
            "--description", "GitHub server",
            "--",
            "npx", "-y", "@modelcontextprotocol/server-github"
        ]

        let command = try MCPCommand.Add.parse(args)
        #expect(command.name == "github")
        #expect(command.env == ["API_KEY=test123", "ANOTHER_VAR=value"])
        #expect(command.timeout == 15.0)
        #expect(command.transport == "stdio")
        #expect(command.description == "GitHub server")
        #expect(command.command == ["npx", "-y", "@modelcontextprotocol/server-github"])
    }

    @Test("Parsing MCP remove with force flag")
    func parsingRemoveWithForce() throws {
        let args = ["test-server", "--force"]
        let command = try MCPCommand.Remove.parse(args)
        #expect(command.name == "test-server")
        #expect(command.force == true)
    }

    @Test("Parsing MCP test with options")
    func parsingTestWithOptions() throws {
        let args = ["github", "--timeout", "5.0", "--show-tools"]
        let command = try MCPCommand.Test.parse(args)
        #expect(command.name == "github")
        #expect(command.timeout == 5.0)
        #expect(command.showTools == true)
    }

    @Test("Parsing MCP info with JSON output")
    func parsingInfoWithJson() throws {
        let args = ["github", "--json-output"]
        let command = try MCPCommand.Info.parse(args)
        #expect(command.name == "github")
        #expect(command.jsonOutput == true)
    }

    @Test("Invalid MCP subcommand should fail parsing")
    func invalidSubcommand() {
        #expect(throws: CommanderProgramError.unknownSubcommand(command: "mcp", name: "invalid-subcommand")) {
            _ = try CommanderRuntimeRouter.resolve(argv: ["peekaboo", "mcp", "invalid-subcommand"])
        }
    }
}

/// Tests for command structure and relationships
@Suite("MCP Command Structure Tests")
struct MCPCommandStructureTests {
    @Test("All MCP subcommands are AsyncParsableCommand")
    func subcommandTypes() {
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
    func subcommandConfigurations() {
        // Test that each subcommand has proper configuration
        #expect(MCPCommand.Serve.commandDescription.abstract.contains("MCP server"))
        #expect(MCPCommand.List.commandDescription.abstract.contains("List configured"))
        #expect(MCPCommand.Add.commandDescription.abstract.contains("Add a new"))
        #expect(MCPCommand.Remove.commandDescription.abstract.contains("Remove an"))
        #expect(MCPCommand.Test.commandDescription.abstract.contains("Test connection"))
        #expect(MCPCommand.Info.commandDescription.abstract.contains("Show detailed"))
        #expect(MCPCommand.Enable.commandDescription.abstract.contains("Enable a disabled"))
        #expect(MCPCommand.Disable.commandDescription.abstract.contains("Disable an"))
        #expect(MCPCommand.Call.commandDescription.abstract.contains("Call a tool"))
        #expect(MCPCommand.Inspect.commandDescription.abstract.contains("Debug MCP"))
    }
}
