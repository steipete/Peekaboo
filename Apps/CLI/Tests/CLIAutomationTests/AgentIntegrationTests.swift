import Foundation
import Testing
@testable import PeekabooCLI

#if !PEEKABOO_SKIP_AUTOMATION

@Suite(
    "Agent Integration Tests",
    .serialized,
    .tags(.integration, .automation),
    .enabled(if: CLITestEnvironment.runAutomationActions)
)
struct AgentIntegrationTests {
    // Only run these tests if explicitly enabled
    let runIntegrationTests = ProcessInfo.processInfo.environment["RUN_AGENT_TESTS"] == "true"

    @Test(
        "Agent can execute simple TextEdit task",
        .enabled(if: ProcessInfo.processInfo.environment["RUN_AGENT_TESTS"] == "true")
    )
    func agentTextEditTask() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            throw TestError.missingAPIKey
        }

        // Build command arguments
        let args = [
            "agent",
            "Open TextEdit and type 'Peekaboo Agent Test'",
            "--json-output",
            "--max-steps", "10",
        ]

        let outputString = try await self.runAgentCommand(args)
        let outputData = outputString.data(using: .utf8) ?? Data()
        let output = try JSONDecoder().decode(AgentTestOutput.self, from: outputData)

        // Verify results
        #expect(output.success == true)
        #expect(output.data?.steps.count ?? 0 > 0)

        // Check that TextEdit commands were used
        let stepCommands: [String] = {
            guard let steps = output.data?.steps else { return [] }
            var commands: [String] = []
            commands.reserveCapacity(steps.count)
            for step in steps {
                guard let command = step.command else { continue }
                commands.append(command)
            }
            return commands
        }()
        #expect(stepCommands.contains("peekaboo_app") || stepCommands.contains("peekaboo_see"))
        #expect(stepCommands.contains("peekaboo_type"))

        // No temp files to remove when running in-process
    }

    @Test(
        "Agent handles window automation",
        .enabled(if: ProcessInfo.processInfo.environment["RUN_AGENT_TESTS"] == "true")
    )
    func agentWindowAutomation() async throws {
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil else {
            throw TestError.missingAPIKey
        }

        let args = [
            "agent",
            "Open Safari, wait 2 seconds, then minimize it",
            "--json-output",
            "--verbose",
        ]

        let outputString = try await self.runAgentCommand(args)
        let outputData = outputString.data(using: .utf8) ?? Data()
        let output = try JSONDecoder().decode(AgentTestOutput.self, from: outputData)

        // Window automation can be flaky due to timing and system state
        withKnownIssue("Window automation may fail if Safari is already running or system is slow") {
            #expect(output.success == true)

            // Verify window commands were used
            let stepCommands: [String] = {
                guard let steps = output.data?.steps else { return [] }
                var commands: [String] = []
                commands.reserveCapacity(steps.count)
                for step in steps {
                    guard let command = step.command else { continue }
                    commands.append(command)
                }
                return commands
            }()
            #expect(stepCommands.contains("peekaboo_app") || stepCommands.contains("peekaboo_window"))
            #expect(stepCommands.contains("peekaboo_sleep"))
        }
    }

    @Test("Agent dry run mode", .enabled(if: ProcessInfo.processInfo.environment["RUN_AGENT_TESTS"] == "true"))
    func agentDryRun() async throws {
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil else {
            throw TestError.missingAPIKey
        }

        let args = [
            "agent",
            "Click on all buttons in the current window",
            "--dry-run",
            "--json-output",
        ]

        let outputString = try await self.runAgentCommand(args)
        let outputData = outputString.data(using: .utf8) ?? Data()
        let output = try JSONDecoder().decode(AgentTestOutput.self, from: outputData)

        #expect(output.success == true)

        // In dry run, outputs should be empty or indicate simulation
        for step in output.data?.steps ?? [] {
            #expect(step.output == nil || step.output?.contains("dry run") == true)
        }
    }

    @Test("Direct Peekaboo invocation", .enabled(if: ProcessInfo.processInfo.environment["RUN_AGENT_TESTS"] == "true"))
    func directPeekabooInvocation() async throws {
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil else {
            throw TestError.missingAPIKey
        }

        // Direct invocation without "agent" subcommand
        let args = [
            "Take a screenshot of the current window",
            "--json-output",
        ]

        let outputString = try await self.runAgentCommand(args)
        let outputData = outputString.data(using: .utf8) ?? Data()
        let output = try JSONDecoder().decode(AgentTestOutput.self, from: outputData)

        #expect(output.success == true)
        let hasImageOrSeeCommand = output.data?.steps.contains { step in
            step.command == "peekaboo_image" || step.command == "peekaboo_see"
        } ?? false
        #expect(hasImageOrSeeCommand == true)
    }

    @Test("Agent respects max steps", .enabled(if: ProcessInfo.processInfo.environment["RUN_AGENT_TESTS"] == "true"))
    func agentMaxSteps() async throws {
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil else {
            throw TestError.missingAPIKey
        }

        let args = [
            "agent",
            "Do 20 different things with various applications",
            "--max-steps", "3",
            "--json-output",
        ]

        let outputString = try await self.runAgentCommand(args)
        let outputData = outputString.data(using: .utf8) ?? Data()
        let output = try JSONDecoder().decode(AgentTestOutput.self, from: outputData)

        // Should stop at 3 steps
        #expect((output.data?.steps.count ?? 0) <= 3)
    }

    private func runAgentCommand(
        _ arguments: [String],
        allowedExitStatuses: Set<Int32> = [0]
    ) async throws -> String {
        let result = try await InProcessCommandRunner.runShared(
            arguments,
            allowedExitCodes: allowedExitStatuses
        )
        return result.stdout.isEmpty ? result.stderr : result.stdout
    }
}

// Test output structures
struct AgentTestOutput: Codable {
    let success: Bool
    let data: AgentResultData?
    let error: ErrorData?

    struct AgentResultData: Codable {
        let steps: [Step]
        let summary: String?
        let success: Bool

        struct Step: Codable {
            let description: String
            let command: String?
            let output: String?
            let screenshot: String?
        }
    }

    struct ErrorData: Codable {
        let code: String
        let message: String
    }
}

enum TestError: Error {
    case missingAPIKey
}

// Tag for integration tests - removed duplicate, using TestTags.swift version
#endif
