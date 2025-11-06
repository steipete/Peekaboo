import Foundation
import Testing

#if !PEEKABOO_SKIP_AUTOMATION
@Suite("Help Command Tests", .tags(.automation), .enabled(if: CLITestEnvironment.runAutomationRead))
struct HelpCommandTests {
    private let peekabooPath: String = {
        if let override = ProcessInfo.processInfo.environment["PEEKABOO_CLI_PATH"], !override.isEmpty {
            return override
        }

        if let resolved = CLITestEnvironment.peekabooBinaryURL()?.path {
            return resolved
        }

        return "./peekaboo"
    }()

    @Test("No arguments shows help")
    func noArgumentsShowsHelp() async throws {
        let output = try await runPeekaboo([])

        // Verify help content is shown
        #expect(output.contains("OVERVIEW: Lightning-fast macOS screenshots"))
        #expect(output.contains("USAGE: peekaboo <subcommand>"))
        #expect(output.contains("SUBCOMMANDS:"))
        #expect(output.contains("image"))
        #expect(output.contains("list"))
        #expect(output.contains("agent"))
    }

    @Test("--help flag shows help")
    func helpFlagShowsHelp() async throws {
        let output = try await runPeekaboo(["--help"])

        // Should show same help as no arguments
        #expect(output.contains("OVERVIEW: Lightning-fast macOS screenshots"))
        #expect(output.contains("USAGE: peekaboo <subcommand>"))
    }

    @Test("help subcommand for each tool")
    func helpForEachSubcommand() async throws {
        let subcommands = [
            ("image", "Capture screenshots"),
            ("list", "List running applications, windows, or check permissions"),
            ("config", "Manage Peekaboo configuration"),
            ("permissions", "Check system permissions required for Peekaboo"),
            ("see", "Capture screen and map UI elements"),
            ("click", "Click on UI elements or coordinates"),
            ("type", "Type text or send keyboard input"),
            ("scroll", "Scroll the mouse wheel in any direction"),
            ("hotkey", "Press keyboard shortcuts and key combinations"),
            ("swipe", "Perform swipe gestures"),
            ("drag", "Perform drag and drop operations"),
            ("move", "Move the mouse cursor to coordinates or UI elements"),
            ("run", "Execute a Peekaboo automation script"),
            ("sleep", "Pause execution for a specified duration"),
            ("clean", "Clean up session cache and temporary files"),
            ("window", "Manipulate application windows"),
            ("menu", "Interact with application menu bar"),
            ("app", "Control applications"),
            ("dock", "Interact with the macOS Dock"),
            ("dialog", "Interact with system dialogs and alerts"),
            ("agent", "Execute complex automation tasks using AI agent")
        ]

        for (subcommand, expectedOverview) in subcommands {
            let output = try await runPeekaboo(["help", subcommand])

            // Each subcommand help should contain OVERVIEW and USAGE
            #expect(output.contains("OVERVIEW:"), "Help for \(subcommand) should contain OVERVIEW")
            #expect(output.contains(expectedOverview), "Help for \(subcommand) should contain '\(expectedOverview)'")
            #expect(output.contains("USAGE:"), "Help for \(subcommand) should contain USAGE")

            // Should not show agent execution output
            #expect(!output.contains("[info] Peekaboo Agent"), "Help for \(subcommand) should not invoke agent")
            #expect(!output.contains("📋 Task:"), "Help for \(subcommand) should not show task execution")
        }
    }

    @Test("help with invalid subcommand")
    func helpWithInvalidSubcommand() async throws {
        // This should show an error, not invoke the agent
        let result = try await runPeekabooWithExitCode(["help", "nonexistent"])

        #expect(result.exitCode != 0)
        #expect(result.output.contains("Error:") || result.output.contains("Unknown subcommand"))
        #expect(!result.output.contains("[info] Peekaboo Agent"))
    }

    @Test("Subcommand --help flag")
    func subcommandHelpFlag() async throws {
        // Test that each subcommand's --help flag works
        let subcommands = ["image", "list", "config", "agent", "see", "click"]

        for subcommand in subcommands {
            let output = try await runPeekaboo([subcommand, "--help"])

            #expect(output.contains("OVERVIEW:"), "\(subcommand) --help should show overview")
            #expect(output.contains("USAGE:"), "\(subcommand) --help should show usage")
            #expect(!output.contains("[info] Peekaboo Agent"), "\(subcommand) --help should not invoke agent")
        }
    }

    // MARK: - Helper Methods

    private func runPeekaboo(_ arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: self.peekabooPath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func runPeekabooWithExitCode(_ arguments: [String]) async throws -> (output: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: self.peekabooPath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return (output, process.terminationStatus)
    }
}
#endif
