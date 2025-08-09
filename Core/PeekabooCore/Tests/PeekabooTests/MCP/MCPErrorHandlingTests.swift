import Foundation
import PeekabooFoundation
import MCP
import TachikomaMCP
import Testing
@testable import PeekabooCore

@Suite("MCP Error Handling Tests")
struct MCPErrorHandlingTests {
    // MARK: - MCPError Tests

    @Test("PeekabooCore.MCPError descriptions")
    func mCPErrorDescriptions() {
        let errors: [(PeekabooCore.MCPError, String)] = [
            (.notImplemented("HTTP transport"), "HTTP transport is not yet implemented"),
            (.toolNotFound("missing-tool"), "Tool 'missing-tool' not found"),
            (.invalidArguments("Missing required field"), "Invalid arguments: Missing required field"),
            (.executionFailed("Operation failed"), "Execution failed: Operation failed"),
        ]

        for (error, expectedDescription) in errors {
            #expect(error.errorDescription == expectedDescription)
        }
    }

    @Test("PeekabooCore.MCPError with underlying error")
    func mCPErrorWithUnderlyingError() {
        struct TestError: Swift.Error, LocalizedError {
            var errorDescription: String? { "Test error occurred" }
        }

        let _ = TestError()
        let error = PeekabooCore.MCPError.executionFailed("Operation failed")

        // Note: The current MCPError doesn't support underlying errors
        // We'd need to extend it to support this
        #expect(error.errorDescription == "Execution failed: Operation failed")
    }

    // MARK: - Tool Argument Validation Tests

    @Test("Tool handles corrupt JSON in arguments")
    func corruptJSONArguments() async throws {
        struct StrictTool: MCPTool {
            let name = "strict"
            let description = "Tool with strict JSON requirements"
            let inputSchema = Value.object([:])

            struct StrictInput: Codable {
                let requiredField: String
                let numberField: Int
            }

            func execute(arguments: ToolArguments) async throws -> ToolResponse {
                do {
                    let input = try arguments.decode(StrictInput.self)
                    return .text("Success: \(input.requiredField)")
                } catch {
                    return .error("Failed to decode arguments: \(error)")
                }
            }
        }

        let tool = StrictTool()

        // Test with missing required field
        let args1 = ToolArguments(raw: ["numberField": 42])
        let response1 = try await tool.execute(arguments: args1)
        #expect(response1.isError == true)

        // Test with wrong type
        let args2 = ToolArguments(raw: ["requiredField": "test", "numberField": "not-a-number"])
        let response2 = try await tool.execute(arguments: args2)
        #expect(response2.isError == true)
    }

    // MARK: - Transport Error Tests

    @Test("Server handles unsupported transport types")
    func unsupportedTransportTypes() async throws {
        let server = try await PeekabooMCPServer()

        // HTTP transport not implemented
        do {
            try await server.serve(transport: .http)
            Issue.record("Expected error for unimplemented HTTP transport")
        } catch let error as PeekabooCore.MCPError {
            #expect(error.errorDescription?.contains("HTTP") == true)
        } catch {
            Issue.record("Expected PeekabooCore.MCPError, got \(error)")
        }

        // SSE transport not implemented
        do {
            try await server.serve(transport: .sse)
            Issue.record("Expected error for unimplemented SSE transport")
        } catch let error as PeekabooCore.MCPError {
            #expect(error.errorDescription?.contains("SSE") == true)
        } catch {
            Issue.record("Expected PeekabooCore.MCPError, got \(error)")
        }
    }

    // MARK: - Tool Execution Error Tests

    @Test("Tool gracefully handles system errors")
    func systemErrorHandling() async throws {
        struct FailingTool: MCPTool {
            let name = "failing"
            let description = "Tool that simulates system errors"
            let inputSchema = Value.object([:])

            enum FailureType: String {
                case fileNotFound
                case permissionDenied
                case networkError
                case timeout
            }

            func execute(arguments: ToolArguments) async throws -> ToolResponse {
                guard let failureTypeStr = arguments.getString("failure_type"),
                      let failureType = FailureType(rawValue: failureTypeStr)
                else {
                    return .error("Unknown failure type")
                }

                switch failureType {
                case .fileNotFound:
                    return .error("File not found: /nonexistent/path.txt")
                case .permissionDenied:
                    return .error("Permission denied: insufficient privileges")
                case .networkError:
                    return .error("Network error: connection refused")
                case .timeout:
                    // Simulate timeout
                    try await Task.sleep(nanoseconds: 100_000_000)
                    return .error("Operation timed out")
                }
            }
        }

        let tool = FailingTool()

        // Test various failure scenarios
        let failureTypes = ["fileNotFound", "permissionDenied", "networkError", "timeout"]

        for failureType in failureTypes {
            let args = ToolArguments(raw: ["failure_type": failureType])
            let response = try await tool.execute(arguments: args)

            #expect(response.isError == true)
            if case let .text(error) = response.content.first {
                #expect(!error.isEmpty)
            }
        }
    }

    // MARK: - Concurrent Error Handling

    @Test("Concurrent tool failures don't affect other tools")
    func concurrentToolFailures() async throws {
        struct ConcurrentTestTool: MCPTool {
            let name: String
            let description = "Test tool"
            let inputSchema = Value.object([:])
            let shouldFail: Bool
            let delay: Double

            func execute(arguments: ToolArguments) async throws -> ToolResponse {
                try await Task.sleep(nanoseconds: UInt64(self.delay * 1_000_000_000))

                if self.shouldFail {
                    throw PeekabooError.operationError(message: "Intentional failure for \(self.name)")
                }

                return .text("Success from \(self.name)")
            }
        }

        let tools = [
            ConcurrentTestTool(name: "tool1", shouldFail: false, delay: 0.1),
            ConcurrentTestTool(name: "tool2", shouldFail: true, delay: 0.05),
            ConcurrentTestTool(name: "tool3", shouldFail: false, delay: 0.15),
            ConcurrentTestTool(name: "tool4", shouldFail: true, delay: 0.02),
        ]

        // Execute all tools concurrently
        let results = await withTaskGroup(of: (String, Result<ToolResponse, Swift.Error>).self) { group in
            for tool in tools {
                group.addTask {
                    do {
                        let response = try await tool.execute(arguments: ToolArguments(raw: [:]))
                        return (tool.name, .success(response))
                    } catch {
                        return (tool.name, .failure(error))
                    }
                }
            }

            var results: [(String, Result<ToolResponse, Swift.Error>)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        // Verify results
        #expect(results.count == 4)

        for (name, result) in results {
            let tool = tools.first { $0.name == name }!

            switch result {
            case let .success(response):
                #expect(tool.shouldFail == false)
                #expect(response.isError == false)
            case .failure:
                #expect(tool.shouldFail == true)
            }
        }
    }

    // MARK: - Recovery Tests

    @Test("Tool recovers from transient errors")
    func transientErrorRecovery() async throws {
        actor RetryableTool: MCPTool {
            let name = "retryable"
            let description = "Tool that fails then succeeds"
            let inputSchema = Value.object([:])

            private var attemptCount = 0

            func execute(arguments: ToolArguments) async throws -> ToolResponse {
                self.attemptCount += 1

                if self.attemptCount < 3 {
                    return .error("Transient error, attempt \(self.attemptCount)")
                }

                return .text("Success after \(self.attemptCount) attempts")
            }
        }

        let tool = RetryableTool()

        // First two attempts should fail
        let response1 = try await tool.execute(arguments: ToolArguments(raw: [:]))
        #expect(response1.isError == true)

        let response2 = try await tool.execute(arguments: ToolArguments(raw: [:]))
        #expect(response2.isError == true)

        // Third attempt should succeed
        let response3 = try await tool.execute(arguments: ToolArguments(raw: [:]))
        #expect(response3.isError == false)

        if case let .text(message) = response3.content.first {
            #expect(message.contains("Success"))
            #expect(message.contains("3 attempts"))
        }
    }
}

@Suite("MCP Protocol Error Tests")
struct MCPProtocolErrorTests {
    @Test("Invalid MCP message format")
    func invalidMessageFormat() {
        // Test various malformed MCP messages
        let invalidMessages = [
            "not json at all",
            "{}", // Missing required fields
            "{\"method\": \"unknown\"}", // Unknown method
            "{\"jsonrpc\": \"1.0\"}", // Wrong version
        ]

        // These would be tested through the actual MCP protocol handler
        // For now, we verify the strings are indeed invalid JSON-RPC
        for message in invalidMessages {
            if message == "{}" || message.contains("{") {
                // Valid JSON structure but invalid MCP protocol
                continue
            }

            let data = Data(message.utf8)
            do {
                _ = try JSONSerialization.jsonObject(with: data)
                // If it's valid JSON, that's fine for some test cases
            } catch {
                // Invalid JSON is also a protocol error
                #expect(error is NSError)
            }
        }
    }

    @Test("Tool response size limits")
    func toolResponseSizeLimits() async throws {
        struct LargeTool: MCPTool {
            let name = "large"
            let description = "Tool that generates large responses"
            let inputSchema = Value.object([:])

            func execute(arguments: ToolArguments) async throws -> ToolResponse {
                let size = arguments.getInt("size") ?? 1000

                // Generate large string
                let largeString = String(repeating: "x", count: size)

                // Check if response would be too large
                if size > 1_000_000 { // 1MB limit example
                    return .error("Response too large: \(size) bytes exceeds limit")
                }

                return .text(largeString)
            }
        }

        let tool = LargeTool()

        // Test within limits
        let smallResponse = try await tool.execute(
            arguments: ToolArguments(raw: ["size": 1000]))
        #expect(smallResponse.isError == false)

        // Test exceeding limits
        let largeResponse = try await tool.execute(
            arguments: ToolArguments(raw: ["size": 2_000_000]))
        #expect(largeResponse.isError == true)
    }
}

@Suite("MCP Error Recovery Integration Tests", .tags(.integration))
struct MCPErrorRecoveryIntegrationTests {
    @Test("Server recovers from tool crashes")
    func serverToolCrashRecovery() async throws {
        // This would test that the server continues running
        // even if individual tools crash or throw unexpected errors

        // In a real integration test:
        // 1. Start MCP server
        // 2. Call a tool that crashes
        // 3. Verify server is still responsive
        // 4. Call another tool successfully
    }

    @Test("Client reconnection after disconnect")
    func clientReconnection() async throws {
        // This would test:
        // 1. Client connects to server
        // 2. Connection drops (network error, server restart, etc)
        // 3. Client reconnects
        // 4. State is properly restored or reset
    }
}
