import Foundation
@testable import peekaboo
import Testing

@Suite("Agent Command Basic Tests")
struct AgentCommandBasicTests {
    @Test("Agent command exists and has correct configuration")
    func agentCommandExists() {
        // Verify the command configuration
        let config = AgentCommand.configuration
        #expect(config.commandName == "agent")
        #expect(config.abstract == "Execute complex automation tasks using AI agent")
        #expect(config.discussion.contains("OpenAI Assistants API"))
    }

    @Test("Agent error types work correctly")
    func agentErrorTypes() {
        // Test error creation and messages
        let missingKeyError = AgentError.missingAPIKey
        #expect(missingKeyError.localizedDescription == "OPENAI_API_KEY environment variable not set")
        #expect(missingKeyError.errorCode == "MISSING_API_KEY")

        let apiError = AgentError.apiError("Test error")
        #expect(apiError.localizedDescription == "API Error: Test error")
        #expect(apiError.errorCode == "API_ERROR")

        let commandError = AgentError.commandFailed("Command failed")
        #expect(commandError.localizedDescription == "Command failed: Command failed")
        #expect(commandError.errorCode == "COMMAND_FAILED")
    }

    @Test("JSON response structures encode correctly")
    func jSONResponseEncoding() throws {
        // Test successful response
        let successResponse = AgentJSONResponse(
            success: true,
            data: AgentCommandBasicTests.TestData(message: "Success"),
            error: nil
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(successResponse)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("\"success\":true"))
        #expect(json.contains("\"message\":\"Success\""))

        // Test error response
        let errorResponse = createAgentErrorResponse(.missingAPIKey)
        let errorData = try encoder.encode(errorResponse)
        let errorJson = String(data: errorData, encoding: .utf8)!

        #expect(errorJson.contains("\"success\":false"))
        #expect(errorJson.contains("MISSING_API_KEY"))
    }

    @Test("Session manager creates and retrieves sessions")
    func sessionManager() async {
        let manager = SessionManager.shared

        // Create a session
        let sessionId = await manager.createSession()
        #expect(!sessionId.isEmpty)

        // Retrieve the session
        let session = await manager.getSession(sessionId)
        #expect(session != nil)
        #expect(session?.id == sessionId)

        // Remove the session
        await manager.removeSession(sessionId)
        let removedSession = await manager.getSession(sessionId)
        #expect(removedSession == nil)
    }

    @Test("Retry configuration calculates delays correctly")
    func retryConfiguration() {
        let config = RetryConfiguration.default

        #expect(config.maxAttempts == 3)
        #expect(config.initialDelay == 1.0)
        #expect(config.maxDelay == 30.0)
        #expect(config.backoffMultiplier == 2.0)

        // Test delay calculation
        #expect(config.delay(for: 0) == 1.0) // First attempt
        #expect(config.delay(for: 1) == 2.0) // Second attempt
        #expect(config.delay(for: 2) == 4.0) // Third attempt
        #expect(config.delay(for: 10) == 30.0) // Should cap at maxDelay
    }

    @Test("Command executor validates arguments")
    func commandExecutorValidation() async throws {
        let executor = PeekabooCommandExecutor(verbose: false)

        // Test invalid JSON
        let result = try await executor.executeFunction(
            name: "peekaboo_see",
            arguments: "invalid json"
        )

        #expect(result.contains("\"success\":false"))
        #expect(result.contains("INVALID_ARGS"))
    }

    // Helper struct for testing
    private struct TestData: Codable {
        let message: String
    }
}
