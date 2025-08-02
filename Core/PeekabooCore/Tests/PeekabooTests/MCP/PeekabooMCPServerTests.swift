import Testing
import Foundation
@testable import PeekabooCore
import MCP
import Logging

@Suite("PeekabooMCPServer Tests")
struct PeekabooMCPServerTests {
    
    @Test("Server initialization creates server with correct capabilities")
    func testServerInitialization() async throws {
        let server = try await PeekabooMCPServer()
        
        // Server should be initialized but we can't directly access private properties
        // We'll test through the tool list functionality
        
        // This test verifies the server can be created without errors
        // More detailed testing would require either:
        // 1. Making some properties internal instead of private
        // 2. Testing through the public API (serve method)
    }
    
    @Test("Server registers all expected tools")
    func testToolRegistration() async throws {
        // Create a mock transport to capture server responses
        let mockTransport = MockTransport()
        let server = try await PeekabooMCPServer()
        
        // We need to test that all tools are registered
        // This would require either exposing the toolRegistry or testing through the protocol
        
        // Expected tools based on the implementation
        let expectedTools = [
            "image", "analyze", "list", "permissions", "sleep",
            "see", "click", "type", "scroll", "hotkey", "swipe", "drag", "move",
            "app", "window", "menu",
            "agent", "dock", "dialog", "space"
        ]
        
        // Without access to internal state, we'd need to test through the MCP protocol
        // This is a limitation of the current design
    }
    
    @Test("Server handles ListTools request")
    func testListToolsHandler() async throws {
        // This test would require setting up a mock transport
        // and sending actual MCP protocol messages
        
        // For now, we can at least verify the server initializes without error
        let server = try await PeekabooMCPServer()
        
        // In a real test, we would:
        // 1. Create a mock transport
        // 2. Send a ListTools request
        // 3. Verify the response contains all expected tools
    }
    
    @Test("Server handles CallTool request for valid tool")
    func testCallToolValidTool() async throws {
        let server = try await PeekabooMCPServer()
        
        // Test would involve:
        // 1. Setting up mock transport
        // 2. Sending CallTool request for "sleep" with duration: 0.1
        // 3. Verifying successful response
    }
    
    @Test("Server handles CallTool request for invalid tool")
    func testCallToolInvalidTool() async throws {
        let server = try await PeekabooMCPServer()
        
        // Test would involve:
        // 1. Setting up mock transport
        // 2. Sending CallTool request for "nonexistent_tool"
        // 3. Verifying error response with appropriate error code
    }
    
    @Test("Server handles Initialize request")
    func testInitializeHandler() async throws {
        let server = try await PeekabooMCPServer()
        
        // Test would verify:
        // 1. Server responds with correct protocol version
        // 2. Server capabilities are properly set
        // 3. Server info contains correct name and version
    }
    
    @Test("Server gracefully handles transport errors")
    func testTransportErrorHandling() async throws {
        let server = try await PeekabooMCPServer()
        
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
        isConnected = true
    }
    
    func disconnect() async {
        isConnected = false
    }
    
    func send(_ data: Data) async throws {
        guard isConnected else {
            throw MockTransportError.disconnected
        }
        if let message = String(data: data, encoding: .utf8) {
            messages.append(message)
        }
    }
    
    func receive() -> AsyncThrowingStream<Data, Swift.Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard isConnected else {
                    continuation.finish(throwing: MockTransportError.disconnected)
                    return
                }
                
                // Return pre-configured responses
                for response in responses {
                    if let data = response.data(using: .utf8) {
                        continuation.yield(data)
                    }
                }
                
                continuation.finish()
            }
        }
    }
    
    func close() async throws {
        await disconnect()
    }
}

enum MockTransportError: Swift.Error {
    case disconnected
}

// MARK: - Integration Test Suite

@Suite("MCP Server Integration Tests", .tags(.integration))
struct MCPServerIntegrationTests {
    
    @Test("Server starts and stops cleanly on stdio transport")
    func testStdioTransportLifecycle() async throws {
        let server = try await PeekabooMCPServer()
        
        // We can't easily test stdio transport in unit tests
        // This would be better as an integration test with actual process spawning
    }
    
    @Test("Server handles concurrent tool calls")
    func testConcurrentToolCalls() async throws {
        let server = try await PeekabooMCPServer()
        
        // Test would involve:
        // 1. Setting up multiple concurrent CallTool requests
        // 2. Verifying all complete successfully
        // 3. Checking for race conditions or deadlocks
    }
    
    @Test("Server maintains session state correctly")
    func testSessionState() async throws {
        let server = try await PeekabooMCPServer()
        
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
    func testToolListingPerformance() async throws {
        let server = try await PeekabooMCPServer()
        
        // Measure time to list tools
        // Should complete in < 10ms
    }
    
    @Test("Tool execution performance for simple tools")
    func testSimpleToolPerformance() async throws {
        let server = try await PeekabooMCPServer()
        
        // Test tools like "sleep" that have minimal overhead
        // Should complete in < 50ms including protocol overhead
    }
}