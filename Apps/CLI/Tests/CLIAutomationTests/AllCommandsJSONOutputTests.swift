import Foundation
import Testing
@testable import PeekabooCLI

#if !PEEKABOO_SKIP_AUTOMATION
@Suite(
    "All Commands JSON Output Support",
    .serialized,
    .tags(.integration),
    .enabled(if: CLITestEnvironment.runAutomationRead)
)
struct AllCommandsJSONOutputTests {
    private static let commandsRequiringJSONOutput: [[String]] = [
        // Basic commands
        ["image"],
        ["permissions"],
        ["see"],
        ["click"],
        ["type"],
        ["scroll"],
        ["hotkey"],
        ["swipe"],
        ["run"],
        ["sleep"],
        ["clean"],
        ["drag"],
        ["agent"],

        // List subcommands
        ["list", "apps"],
        ["list", "windows"],
        ["list", "permissions"],

        // Config subcommands
        ["config", "init"],
        ["config", "show"],
        ["config", "edit"],
        ["config", "validate"],

        // Window subcommands
        ["window", "close"],
        ["window", "minimize"],
        ["window", "maximize"],
        ["window", "focus"],
        ["window", "move"],
        ["window", "resize"],

        // App subcommands
        ["app", "launch"],
        ["app", "quit"],
        ["app", "hide"],
        ["app", "unhide"],
        ["app", "switch"],
        ["app", "list"],

        // Menu subcommands
        ["menu", "click"],

        // Dock subcommands
        ["dock", "launch"],
        ["dock", "right-click"],
        ["dock", "show"],
        ["dock", "hide"],
        ["dock", "list"],

        // Dialog subcommands
        ["dialog", "click"],
        ["dialog", "input"],
        ["dialog", "file"],
        ["dialog", "dismiss"],
        ["dialog", "list"],
    ]
    @Test("All commands support --json-output flag")
    func verifyAllCommandsHaveJSONOutputFlag() async throws {
        var missingJSONOutputCommands: [String] = []

        for commandArgs in Self.commandsRequiringJSONOutput {
            let commandName = commandArgs.joined(separator: " ")
            let result = try await InProcessCommandRunner.runShared(commandArgs + ["--help"])
            let output = result.combinedOutput

            if !output.contains("--json-output") {
                missingJSONOutputCommands.append(commandName)
            }
        }

        #expect(
            missingJSONOutputCommands.isEmpty,
            "Commands missing --json-output flag: \(missingJSONOutputCommands.joined(separator: ", "))"
        )
    }

    @Test("Commands produce valid JSON with --json-output")
    func verifyCommandsProduceValidJSON() async throws {
        // Commands that can be safely tested without side effects
        let testableCommands: [(args: [String], description: String)] = [
            (["permissions", "--json-output"], "permissions"),
            (["permissions", "check", "--json-output"], "permissions check"),
            (["list", "apps", "--json-output"], "list apps"),
            (["list", "permissions", "--json-output"], "list permissions"),
            (["sleep", "50", "--json-output"], "sleep"),
            (["clean", "--all-sessions", "--dry-run", "--json-output"], "clean (dry run)"),
        ]
        var invalidJSONCommands: [String] = []

        for (commandArgs, description) in testableCommands {
            let result = try await InProcessCommandRunner.runShared(commandArgs)
            let outputString = result.combinedOutput

            // Skip empty output (some commands might not output anything in test environment)
            guard !outputString.isEmpty else { continue }

            // Try to parse as JSON
            do {
                let jsonData = outputString.data(using: .utf8) ?? Data()
                _ = try JSONSerialization.jsonObject(with: jsonData)
            } catch {
                invalidJSONCommands.append("\(description): \(error.localizedDescription)")
            }
        }

        #expect(
            invalidJSONCommands.isEmpty,
            "Commands producing invalid JSON: \(invalidJSONCommands.joined(separator: "\n"))"
        )
    }

    @Test("JSON output follows consistent schema")
    func verifyJSONOutputSchema() async throws {
        let result = try await InProcessCommandRunner.runShared(["permissions", "--json-output"])
        let data = Data(result.combinedOutput.utf8)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Issue.record("Failed to parse JSON output from permissions command")
            return
        }

        // Verify standard JSON schema
        #expect(json["success"] != nil, "JSON should contain 'success' field")

        if let success = json["success"] as? Bool {
            if success {
                // Successful responses should have data
                let hasData = json["data"] != nil
                let hasOtherFields = json.keys.count > 1
                #expect(
                    hasData || hasOtherFields,
                    "Successful JSON responses should contain data or other result fields"
                )
            } else {
                // Failed responses should have error
                #expect(
                    json["error"] != nil,
                    "Failed JSON responses should contain 'error' field"
                )

                if let error = json["error"] as? [String: Any] {
                    #expect(error["message"] != nil, "Error should contain 'message'")
                    #expect(error["code"] != nil, "Error should contain 'code'")
                }
            }
        }
    }

    @Test("Error responses use JSON format")
    func verifyErrorResponsesUseJSON() async throws {
        // Test commands that will produce errors
        let errorCommands: [(args: [String], description: String)] = [
            (["image", "--app", "NonExistentApp_XYZ_123", "--json-output"], "image missing app"),
            (["see", "--app", "NonExistentApp_XYZ_123", "--json-output"], "see missing app"),
            (["sleep", "--json-output", "--", "-100"], "negative sleep duration"),
            (["run", "missing.peekaboo.json", "--json-output"], "missing automation script"),
        ]
        var nonJSONErrors: [String] = []

        for (commandArgs, description) in errorCommands {
            let result = try await InProcessCommandRunner.runWithSharedServices(commandArgs)
            let outputString = result.stdout
            let errorString = result.stderr

            // Try to find JSON in either output
            let jsonString = !outputString.isEmpty ? outputString : errorString

            guard !jsonString.isEmpty else {
                nonJSONErrors.append("\(description): No output produced")
                continue
            }

            // Try to parse as JSON
            do {
                let jsonData = jsonString.data(using: .utf8) ?? Data()
                if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    // Verify it's an error response
                    let isError = json["success"] as? Bool == false
                    let hasError = json["error"] != nil

                    if !isError || !hasError {
                        nonJSONErrors.append("\(description): JSON doesn't follow error format")
                    }
                } else {
                    nonJSONErrors.append("\(description): Not a JSON object")
                }
            } catch {
                nonJSONErrors.append("\(description): Invalid JSON - \(error)")
            }
        }

        #expect(
            nonJSONErrors.isEmpty,
            "Commands not producing JSON errors: \(nonJSONErrors.joined(separator: "\n"))"
        )
    }

    @Test("Subcommands properly inherit JSON output")
    func verifySubcommandsInheritJSONOutput() async throws {
        // Test that subcommands can be called with --json-output
        let subcommandTests: [(args: [String], description: String)] = [
            (["app", "list", "--json-output"], "app list"),
            (["config", "show", "--json-output"], "config show"),
            (["list", "permissions", "--json-output"], "list permissions"),
        ]
        var failedSubcommands: [String] = []

        for (commandArgs, description) in subcommandTests {
            let result = try await InProcessCommandRunner.runWithSharedServices(commandArgs)

            if result.exitStatus != 0 {
                let errorString = result.stderr
                if errorString.contains("Unknown option"), errorString.contains("json-output") {
                    failedSubcommands.append(description)
                }
            }
        }

        #expect(
            failedSubcommands.isEmpty,
            "Subcommands not accepting --json-output: \(failedSubcommands.joined(separator: ", "))"
        )
    }
}
#endif
