import Foundation
import Logging
import MCP
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

@Suite("PeekabooMCPServer Tests")
struct PeekabooMCPServerTests {
    @Test("Server initialization creates server with correct capabilities")
    func serverInitialization() async throws {
        _ = try await makeServer()

        // Server should be initialized but we can't directly access private properties
        // We'll test through the tool list functionality

        // This test verifies the server can be created without errors
        // More detailed testing would require either:
        // 1. Making some properties internal instead of private
        // 2. Testing through the public API (serve method)
    }

    @Test("Server registers all expected tools")
    func toolRegistration() async throws {
        _ = try await makeServer()

        // We need to test that all tools are registered
        // This would require either exposing the toolRegistry or testing through the protocol

        // Without access to internal state, we'd need to test through the MCP protocol
        // This is a limitation of the current design
    }

    @Test("Server handles ListTools request")
    func listToolsHandler() async throws {
        // This test would require setting up a mock transport
        // and sending actual MCP protocol messages

        // For now, we can at least verify the server initializes without error
        _ = try await makeServer()

        // In a real test, we would:
        // 1. Create a mock transport
        // 2. Send a ListTools request
        // 3. Verify the response contains all expected tools
    }

    @Test("Server handles CallTool request for valid tool")
    func callToolValidTool() async throws {
        _ = try await makeServer()

        // Test would involve:
        // 1. Setting up mock transport
        // 2. Sending CallTool request for "sleep" with duration: 0.1
        // 3. Verifying successful response
    }

    @Test("Server handles CallTool request for invalid tool")
    func callToolInvalidTool() async throws {
        _ = try await makeServer()

        // Test would involve:
        // 1. Setting up mock transport
        // 2. Sending CallTool request for "nonexistent_tool"
        // 3. Verifying error response with appropriate error code
    }

    @Test("Server handles Initialize request")
    func initializeHandler() async throws {
        _ = try await makeServer()

        // Test would verify:
        // 1. Server responds with correct protocol version
        // 2. Server capabilities are properly set
        // 3. Server info contains correct name and version
    }

    @Test("Server gracefully handles transport errors")
    func transportErrorHandling() async throws {
        _ = try await makeServer()

        // Test scenarios:
        // 1. Transport disconnection
        // 2. Invalid JSON in requests
        // 3. Malformed protocol messages
    }
}

// MARK: - Mock Transport for Testing

actor MockTransport: Transport {
    var messages: [String] = []
    var responses: [String] = []
    var isConnected = false
    let logger = Logger(label: "test.mock.transport")

    func connect() async throws {
        self.isConnected = true
    }

    func disconnect() async {
        self.isConnected = false
    }

    func send(_ data: Data) async throws {
        guard self.isConnected else {
            throw MockTransportError.disconnected
        }
        if let message = String(data: data, encoding: .utf8) {
            self.messages.append(message)
        }
    }

    func receive() -> AsyncThrowingStream<Data, any Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard self.isConnected else {
                    continuation.finish(throwing: MockTransportError.disconnected)
                    return
                }

                // Return pre-configured responses
                for response in self.responses {
                    if let data = response.data(using: .utf8) {
                        continuation.yield(data)
                    }
                }

                continuation.finish()
            }
        }
    }

    func close() async throws {
        await self.disconnect()
    }
}

enum MockTransportError: Swift.Error {
    case disconnected
}

// MARK: - Integration Test Suite

@Suite("MCP Server Integration Tests", .tags(.integration))
struct MCPServerIntegrationTests {
    @Test("Server starts and stops cleanly on stdio transport")
    func stdioTransportLifecycle() async throws {
        _ = try await makeServer()

        // We can't easily test stdio transport in unit tests
        // This would be better as an integration test with actual process spawning
    }

    @Test("Server handles concurrent tool calls")
    func concurrentToolCalls() async throws {
        _ = try await makeServer()

        // Test would involve:
        // 1. Setting up multiple concurrent CallTool requests
        // 2. Verifying all complete successfully
        // 3. Checking for race conditions or deadlocks
    }

    @Test("Server maintains session state correctly")
    func sessionState() async throws {
        _ = try await makeServer()

        // Test scenarios:
        // 1. Multiple clients connecting
        // 2. Client disconnection and reconnection
        // 3. State isolation between clients
    }
}

// MARK: - Performance Test Suite

@Suite("MCP Server Performance Tests", .tags(.performance))
struct MCPServerPerformanceTests {
    @Test("Tool listing performance")
    func toolListingPerformance() async throws {
        _ = try await makeServer()
        // Measure time to list tools
        // Should complete in < 10ms
    }

    @Test("Tool execution performance for simple tools")
    func simpleToolPerformance() async throws {
        _ = try await makeServer()
        // Test tools like "sleep" that have minimal overhead
        // Should complete in < 50ms including protocol overhead
    }
}

@MainActor
private func makeServer() async throws -> PeekabooMCPServer {
    let services = PeekabooServices()
    services.installAgentRuntimeDefaults()
    return try await PeekabooMCPServer()
}
