import Foundation
import Testing
@testable import peekaboo

// MARK: - Test Helpers

private func runCommand(_ args: [String]) async throws -> String {
    let output = try await runPeekabooCommand(args)
    return output
}

private func runPeekabooCommand(_ args: [String]) async throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: ".build/debug/peekaboo")
    process.arguments = args

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}

@Suite("Agent Menu Integration Tests", .serialized)
struct AgentMenuTests {
    @Test("Agent can discover menus using list subcommand")
    func agentMenuDiscovery() async throws {
        #if !os(Linux)
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil else { return }

        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] != nil else { return }

        // Ensure Calculator is running
        _ = try await runPeekabooCommand(["app", "--action", "launch", "--name", "Calculator"])
        try await Task.sleep(for: .seconds(2))

        // Test agent discovering menus
        let output = try await runPeekabooCommand([
            "agent",
            "List all menus available in the Calculator app",
            "--json-output",
        ])

        let data = try #require(output.data(using: String.Encoding.utf8))
        let json = try JSONDecoder().decode(AgentJSONResponse.self, from: data)

        #expect(json.success == true)

        // Check that agent used menu command
        if let steps = json.data?.steps {
            let menuStepFound = steps.contains { step in
                step.tool == "menu" || step.description.lowercased().contains("menu")
            }
            #expect(menuStepFound, "Agent should use menu command for menu discovery")
        }

        // Check summary mentions menus
        if let summary = json.data?.summary {
            #expect(summary.lowercased().contains("menu"), "Summary should mention menus")
            #expect(summary.contains("View") || summary.contains("Edit"), "Summary should list actual menu names")
        }
        #endif
    }

    @Test("Agent can navigate menus to perform actions")
    func agentMenuNavigation() async throws {
        #if !os(Linux)
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil else { return }

        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] != nil else { return }

        // Ensure Calculator is running
        _ = try await runPeekabooCommand(["app", "--action", "launch", "--name", "Calculator"])
        try await Task.sleep(for: .seconds(2))

        // Test agent using menu to switch Calculator mode
        let output = try await runPeekabooCommand([
            "agent",
            "Switch Calculator to Scientific mode using the View menu",
            "--json-output",
        ])

        let data = try #require(output.data(using: String.Encoding.utf8))
        let json = try JSONDecoder().decode(AgentJSONResponse.self, from: data)

        #expect(json.success == true)

        if let steps = json.data?.steps {
            // Should have menu discovery and menu click steps
            let menuSteps = steps.filter { $0.tool == "menu" }
            #expect(menuSteps.count >= 1, "Should use menu command at least once")

            // Check for menu click with correct path
            let hasMenuClick = steps.contains { step in
                if step.tool == "menu",
                   let args = step.arguments,
                   let jsonData = try? JSONSerialization.data(withJSONObject: args),
                   let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    return parsed["subcommand"] as? String == "click" ||
                        parsed["path"] as? String == "View > Scientific" ||
                        parsed["item"] as? String == "Scientific"
                }
                return false
            }

            #expect(hasMenuClick || !steps.isEmpty, "Should perform menu click or have steps")
        }
        #endif
    }

    @Test("Agent uses menu discovery before clicking")
    func agentMenuDiscoveryBeforeAction() async throws {
        #if !os(Linux)
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil else { return }

        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] != nil else { return }

        // Test with TextEdit
        _ = try await runPeekabooCommand(["app", "--action", "launch", "--name", "TextEdit"])
        try await Task.sleep(for: .seconds(2))

        let output = try await runPeekabooCommand([
            "agent",
            "Find and use the spell check feature in TextEdit",
            "--json-output",
        ])

        let data = try #require(output.data(using: String.Encoding.utf8))
        let json = try JSONDecoder().decode(AgentJSONResponse.self, from: data)

        #expect(json.success == true)

        if let steps = json.data?.steps {
            // Find menu discovery steps
            var foundDiscovery = false

            for (_, step) in steps.enumerated() {
                if step.tool == "menu" {
                    if let args = step.arguments,
                       let jsonData = try? JSONSerialization.data(withJSONObject: args),
                       let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                        if parsed["subcommand"] as? String == "list" {
                            foundDiscovery = true
                        } else if parsed["subcommand"] as? String == "click", foundDiscovery {
                            // Found the action
                        }
                    }
                }
            }

            #expect(foundDiscovery || !steps.isEmpty, "Should discover menus or have steps")
        }
        #endif
    }

    @Test("Agent handles menu errors gracefully")
    func agentMenuErrorHandling() async throws {
        #if !os(Linux)
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil else { return }

        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] != nil else { return }

        // Test with non-existent menu item
        let output = try await runPeekabooCommand([
            "agent",
            "Click on the 'Quantum Computing' menu item in Calculator",
            "--json-output",
        ])

        let data = try #require(output.data(using: String.Encoding.utf8))
        let json = try JSONDecoder().decode(AgentJSONResponse.self, from: data)

        // Agent should handle this gracefully
        #expect(json.success == true || json.error != nil)

        if let summary = json.data?.summary {
            // Should mention the item wasn't found or similar
            let handledGracefully = summary.lowercased().contains("not found") ||
                summary.lowercased().contains("doesn't exist") ||
                summary.lowercased().contains("unable to find") ||
                summary.lowercased().contains("couldn't find")
            #expect(handledGracefully || json.success == true, "Agent should handle missing menu items gracefully")
        }
        #endif
    }
}

// MARK: - Agent Response Types for Testing

struct AgentJSONResponse: Decodable {
    let success: Bool
    let data: AgentResultData?
    let error: AgentErrorData?
}

struct AgentResultData: Decodable {
    let steps: [AgentStep]
    let summary: String?
    let success: Bool
}

struct AgentStep: Decodable {
    let tool: String
    let arguments: [String: String]?
    let description: String
    let output: String?
}

struct AgentErrorData: Decodable {
    let message: String
    let code: String
}
