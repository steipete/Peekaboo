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
        #expect(discussion.contains("--verbose"))
        #expect(discussion.contains("--json-output"))
    }

    @Test("ToolsCommand default values")
    func toolsCommandDefaults() throws {
        let command = try ToolsCommand.parse([])

        #expect(command.verbose == false)
        #expect(command.jsonOutput == false)
        #expect(command.noSort == false)
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

    @Test("ToolsCommand argument parsing - no sort")
    func argumentParsingNoSort() throws {
        let args = ["--no-sort"]
        let command = try ToolsCommand.parse(args)

        #expect(command.noSort == true)
    }

    @Test("ToolsCommand description property")
    func descriptionProperty() throws {
        let command = try ToolsCommand.parse([])
        #expect(command.description == "Tools command for listing and filtering available tools")
    }
}

/// Mock tests to verify command structure without execution
@Suite("Tools Command Structure Tests", .tags(.safe))
struct ToolsCommandStructureTests {
    @Test("Command has required AsyncParsableCommand conformance")
    func asyncParsableCommandConformance() throws {
        let command = try ToolsCommand.parse([])

        #expect(type(of: command) == ToolsCommand.self)
    }

    @Test("Command configuration is properly set")
    func commandConfigurationProperties() {
        let config = ToolsCommand.commandDescription

        #expect(config.commandName == "tools")
        #expect(!config.abstract.isEmpty)
        #expect(config.discussion != nil)

        let discussion = config.discussion ?? ""
        #expect(discussion.contains("peekaboo tools"))
        #expect(discussion.contains("Examples:"))
        #expect(discussion.contains("--verbose"))
        #expect(discussion.contains("--json-output"))
    }

    @Test("Command properties have correct types and attributes")
    func commandProperties() throws {
        let command = try ToolsCommand.parse([])

        #expect(type(of: command.verbose) == Bool.self)
        #expect(type(of: command.jsonOutput) == Bool.self)
        #expect(type(of: command.noSort) == Bool.self)
    }
}
