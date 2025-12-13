import Foundation
import PeekabooCore
import Testing
@testable import PeekabooCLI

#if !PEEKABOO_SKIP_AUTOMATION
@Suite("Help Command Tests", .tags(.automation), .enabled(if: CLITestEnvironment.runAutomationRead))
struct HelpCommandTests {
    @Test("No arguments shows help")
    func noArgumentsShowsHelp() async throws {
        let output = try await runPeekaboo([]).stdout

        // Verify help content is shown
        #expect(output.contains("Usage"))
        #expect(output.contains("polter peekaboo <command>"))
        #expect(output.contains("Core Commands"))
        #expect(output.contains("image"))
        #expect(output.contains("list"))
        #expect(output.contains("agent"))
        #expect(output.contains("Global Runtime Flags"))
        #expect(output.contains("--json/-j"))
    }

    @Test("--help flag shows help")
    func helpFlagShowsHelp() async throws {
        let output = try await runPeekaboo(["--help"]).stdout

        // Should show same help as no arguments
        #expect(output.contains("Usage"))
        #expect(output.contains("polter peekaboo <command>"))
    }

    @Test("help subcommand for each tool")
    func helpForEachSubcommand() async throws {
        let subcommands = [
            "image",
            "list",
            "config",
            "permissions",
            "see",
            "click",
            "type",
            "scroll",
            "hotkey",
            "swipe",
            "drag",
            "move",
            "run",
            "sleep",
            "clean",
            "window",
            "menu",
            "app",
            "dock",
            "dialog",
            "agent",
        ]

        for subcommand in subcommands {
            let output = try await runPeekaboo(["help", subcommand]).stdout

            // Each subcommand help should contain a usage card + global flags.
            #expect(output.contains("Usage"), "Help for \(subcommand) should contain Usage")
            #expect(output.contains("polter peekaboo \(subcommand)"), "Help for \(subcommand) should contain usage line")
            #expect(output.contains("Global Runtime Flags"), "Help for \(subcommand) should mention global runtime flags")
            #expect(output.contains("--json"), "Help for \(subcommand) should include JSON flag")

            // Should not show agent execution output
            #expect(!output.contains("[info] Peekaboo Agent"), "Help for \(subcommand) should not invoke agent")
            #expect(!output.contains("📋 Task:"), "Help for \(subcommand) should not show task execution")
        }
    }

    @Test("help with invalid subcommand")
    func helpWithInvalidSubcommand() async throws {
        // This should show an error, not invoke the agent
        let result = try await runPeekaboo(["help", "nonexistent"])

        #expect(result.exitStatus != 0)
        let output = result.stdout.isEmpty ? result.stderr : result.stdout
        #expect(output.contains("Error:") || output.contains("Unknown subcommand"))
        #expect(!output.contains("[info] Peekaboo Agent"))
    }

    @Test("Subcommand --help flag")
    func subcommandHelpFlag() async throws {
        // Test that each subcommand's --help flag works
        let subcommands = ["image", "list", "config", "agent", "see", "click"]

        for subcommand in subcommands {
            let output = try await runPeekaboo([subcommand, "--help"]).stdout

            #expect(output.contains("Usage"), "\(subcommand) --help should show usage")
            #expect(output.contains("Global Runtime Flags"), "\(subcommand) --help should mention global flags")
            #expect(!output.contains("[info] Peekaboo Agent"), "\(subcommand) --help should not invoke agent")
        }
    }

    // MARK: - Helper Methods

    private func runPeekaboo(_ arguments: [String]) async throws -> CommandRunResult {
        try await InProcessCommandRunner.runWithSharedServices(arguments)
    }
}
#endif
