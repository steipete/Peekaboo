import Foundation
import Testing
@testable import peekaboo

@Suite("Agent Integration Tests", .serialized, .tags(.integration))
struct AgentIntegrationTests {
    // Only run these tests if explicitly enabled
    let runIntegrationTests = ProcessInfo.processInfo.environment["RUN_AGENT_TESTS"] == "true"

    @Test(
        "Agent can execute simple TextEdit task",
        .enabled(if: ProcessInfo.processInfo.environment["RUN_AGENT_TESTS"] == "true"))
    func agentTextEditTask() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            throw TestError.missingAPIKey
        }

        // Create a temporary file to capture output
        let outputFile = FileManager.default.temporaryDirectory.appendingPathComponent("agent-test-\(UUID()).json")

        // Build command arguments
        let args = [
            "agent",
            "Open TextEdit and type 'Peekaboo Agent Test'",
            "--json-output",
            "--max-steps", "10",
        ]

        // Execute the command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        process.arguments = args
        process.standardOutput = FileHandle(forWritingAtPath: outputFile.path)
        process.standardError = FileHandle.standardError

        process.environment = ProcessInfo.processInfo.environment
        process.environment?["OPENAI_API_KEY"] = apiKey

        try process.run()
        process.waitUntilExit()

        // Read and parse output
        let outputData = try Data(contentsOf: outputFile)
        let output = try JSONDecoder().decode(AgentTestOutput.self, from: outputData)

        // Verify results
        #expect(output.success == true)
        #expect(output.data?.steps.count ?? 0 > 0)

        // Check that TextEdit commands were used
        let stepCommands = output.data?.steps.map(\.command) ?? []
        #expect(stepCommands.contains("peekaboo_app") || stepCommands.contains("peekaboo_see"))
        #expect(stepCommands.contains("peekaboo_type"))

        // Clean up
        try? FileManager.default.removeItem(at: outputFile)
    }

    @Test(
        "Agent handles window automation",
        .enabled(if: ProcessInfo.processInfo.environment["RUN_AGENT_TESTS"] == "true"))
    func agentWindowAutomation() async throws {
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil else {
            throw TestError.missingAPIKey
        }

        let outputFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-window-test-\(UUID()).json")

        let args = [
            "agent",
            "Open Safari, wait 2 seconds, then minimize it",
            "--json-output",
            "--verbose",
        ]

        let process = Process()
        process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        process.arguments = args
        process.standardOutput = FileHandle(forWritingAtPath: outputFile.path)

        try process.run()
        process.waitUntilExit()

        let outputData = try Data(contentsOf: outputFile)
        let output = try JSONDecoder().decode(AgentTestOutput.self, from: outputData)

        #expect(output.success == true)

        // Verify window commands were used
        let stepCommands = output.data?.steps.map(\.command) ?? []
        #expect(stepCommands.contains("peekaboo_app") || stepCommands.contains("peekaboo_window"))
        #expect(stepCommands.contains("peekaboo_sleep"))

        try? FileManager.default.removeItem(at: outputFile)
    }

    @Test("Agent dry run mode", .enabled(if: ProcessInfo.processInfo.environment["RUN_AGENT_TESTS"] == "true"))
    func agentDryRun() async throws {
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil else {
            throw TestError.missingAPIKey
        }

        let outputFile = FileManager.default.temporaryDirectory.appendingPathComponent("agent-dry-run-\(UUID()).json")

        let args = [
            "agent",
            "Click on all buttons in the current window",
            "--dry-run",
            "--json-output",
        ]

        let process = Process()
        process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        process.arguments = args
        process.standardOutput = FileHandle(forWritingAtPath: outputFile.path)

        try process.run()
        process.waitUntilExit()

        let outputData = try Data(contentsOf: outputFile)
        let output = try JSONDecoder().decode(AgentTestOutput.self, from: outputData)

        #expect(output.success == true)

        // In dry run, outputs should be empty or indicate simulation
        for step in output.data?.steps ?? [] {
            #expect(step.output == nil || step.output?.contains("dry run") == true)
        }

        try? FileManager.default.removeItem(at: outputFile)
    }

    @Test("Direct Peekaboo invocation", .enabled(if: ProcessInfo.processInfo.environment["RUN_AGENT_TESTS"] == "true"))
    func directPeekabooInvocation() async throws {
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil else {
            throw TestError.missingAPIKey
        }

        let outputFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("direct-invocation-\(UUID()).json")

        // Direct invocation without "agent" subcommand
        let args = [
            "Take a screenshot of the current window",
            "--json-output",
        ]

        let process = Process()
        process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        process.arguments = args
        process.standardOutput = FileHandle(forWritingAtPath: outputFile.path)

        try process.run()
        process.waitUntilExit()

        let outputData = try Data(contentsOf: outputFile)
        let output = try JSONDecoder().decode(AgentTestOutput.self, from: outputData)

        #expect(output.success == true)
        #expect(output.data?.steps.contains { $0.command == "peekaboo_image" || $0.command == "peekaboo_see" } == true)

        try? FileManager.default.removeItem(at: outputFile)
    }

    @Test("Agent respects max steps", .enabled(if: ProcessInfo.processInfo.environment["RUN_AGENT_TESTS"] == "true"))
    func agentMaxSteps() async throws {
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil else {
            throw TestError.missingAPIKey
        }

        let outputFile = FileManager.default.temporaryDirectory.appendingPathComponent("max-steps-\(UUID()).json")

        let args = [
            "agent",
            "Do 20 different things with various applications",
            "--max-steps", "3",
            "--json-output",
        ]

        let process = Process()
        process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        process.arguments = args
        process.standardOutput = FileHandle(forWritingAtPath: outputFile.path)

        try process.run()
        process.waitUntilExit()

        let outputData = try Data(contentsOf: outputFile)
        let output = try JSONDecoder().decode(AgentTestOutput.self, from: outputData)

        // Should stop at 3 steps
        #expect((output.data?.steps.count ?? 0) <= 3)

        try? FileManager.default.removeItem(at: outputFile)
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
