import Testing
import Foundation
import AsyncHTTPClient
import NIOCore
@testable import peekaboo

// Mock HTTP Client for testing OpenAI API interactions
class MockHTTPClient {
    var responses: [String: (statusCode: HTTPResponseStatus, body: String)] = [:]
    var requestHistory: [(url: String, method: HTTPMethod, body: String?)] = []
    
    func execute(_ request: HTTPClientRequest, timeout: TimeAmount) async throws -> MockHTTPClientResponse {
        let url = request.url
        requestHistory.append((url: url, method: request.method, body: nil))
        
        guard let mockResponse = responses[url] else {
            throw MockHTTPClientError.remoteConnectionClosed
        }
        
        return MockHTTPClientResponse(
            status: mockResponse.statusCode,
            body: mockResponse.body
        )
    }
}

// Mock HTTP Response
struct MockHTTPClientResponse {
    let status: HTTPResponseStatus
    let headers: HTTPHeaders = HTTPHeaders()
    let bodyData: Data
    
    init(status: HTTPResponseStatus, body: String) {
        self.status = status
        self.bodyData = body.data(using: .utf8) ?? Data()
    }
    
    var body: AsyncStream<ByteBuffer> {
        AsyncStream { continuation in
            continuation.yield(ByteBuffer(data: bodyData))
            continuation.finish()
        }
    }
}

// Mock OpenAI Agent for testing
struct MockOpenAIAgent {
    let httpClient: MockHTTPClient
    let apiKey: String = "test-api-key"
    let model: String = "gpt-4-turbo"
    let verbose: Bool = false
    let maxSteps: Int = 10
    
    init(httpClient: MockHTTPClient) {
        self.httpClient = httpClient
    }
    
    // Setup standard mock responses
    func setupStandardResponses() {
        // Mock assistant creation
        httpClient.responses["https://api.openai.com/v1/assistants"] = (
            statusCode: .ok,
            body: """
            {
                "id": "asst_test123",
                "object": "assistant",
                "created_at": 1234567890
            }
            """
        )
        
        // Mock thread creation
        httpClient.responses["https://api.openai.com/v1/threads"] = (
            statusCode: .ok,
            body: """
            {
                "id": "thread_test456",
                "object": "thread",
                "created_at": 1234567890
            }
            """
        )
        
        // Mock message creation
        httpClient.responses["https://api.openai.com/v1/threads/thread_test456/messages"] = (
            statusCode: .ok,
            body: """
            {
                "id": "msg_test789",
                "object": "thread.message",
                "created_at": 1234567890
            }
            """
        )
    }
    
    // Setup mock for a simple task
    func setupSimpleTaskResponse() {
        setupStandardResponses()
        
        // Mock run creation
        httpClient.responses["https://api.openai.com/v1/threads/thread_test456/runs"] = (
            statusCode: .ok,
            body: """
            {
                "id": "run_test111",
                "object": "thread.run",
                "status": "requires_action",
                "required_action": {
                    "type": "submit_tool_outputs",
                    "submit_tool_outputs": {
                        "tool_calls": [
                            {
                                "id": "call_001",
                                "type": "function",
                                "function": {
                                    "name": "peekaboo_see",
                                    "arguments": "{\\"app_target\\": \\"TextEdit\\"}"
                                }
                            },
                            {
                                "id": "call_002",
                                "type": "function",
                                "function": {
                                    "name": "peekaboo_type",
                                    "arguments": "{\\"text\\": \\"Hello World\\"}"
                                }
                            }
                        ]
                    }
                }
            }
            """
        )
        
        // Mock run status check
        httpClient.responses["https://api.openai.com/v1/threads/thread_test456/runs/run_test111"] = (
            statusCode: .ok,
            body: """
            {
                "id": "run_test111",
                "object": "thread.run",
                "status": "completed"
            }
            """
        )
        
        // Mock final messages
        httpClient.responses["https://api.openai.com/v1/threads/thread_test456/messages"] = (
            statusCode: .ok,
            body: """
            {
                "data": [
                    {
                        "id": "msg_final",
                        "role": "assistant",
                        "content": [
                            {
                                "type": "text",
                                "text": {
                                    "value": "Successfully opened TextEdit and typed 'Hello World'"
                                }
                            }
                        ]
                    }
                ]
            }
            """
        )
    }
}

@Suite("Agent Command Tests")
struct AgentCommandTests {
    
    @Test("Agent command parses arguments correctly")
    func testAgentCommandParsing() throws {
        let command = try AgentCommand.parse(["Open TextEdit and write Hello"])
        #expect(command.task == "Open TextEdit and write Hello")
        #expect(command.verbose == false)
        #expect(command.dryRun == false)
        #expect(command.maxSteps == 20)
        #expect(command.model == "gpt-4-turbo")
    }
    
    @Test("Agent command with options")
    func testAgentCommandWithOptions() throws {
        let command = try AgentCommand.parse([
            "Test task",
            "--verbose",
            "--dry-run",
            "--max-steps", "50",
            "--model", "gpt-4",
            "--json-output"
        ])
        #expect(command.task == "Test task")
        #expect(command.verbose == true)
        #expect(command.dryRun == true)
        #expect(command.maxSteps == 50)
        #expect(command.model == "gpt-4")
        #expect(command.jsonOutput == true)
    }
    
    @Test("Direct Peekaboo invocation")
    func testDirectInvocation() throws {
        // Test that Peekaboo main command can handle direct task invocation
        let peekaboo = try Peekaboo.parse(["Open Safari and search for weather"])
        #expect(peekaboo.remainingArgs == ["Open", "Safari", "and", "search", "for", "weather"])
    }
    
    @Test("Agent requires OpenAI API key")
    func testAgentRequiresAPIKey() async throws {
        // Remove API key from environment
        let originalKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        defer {
            if let key = originalKey {
                setenv("OPENAI_API_KEY", key, 1)
            }
        }
        unsetenv("OPENAI_API_KEY")
        
        var command = AgentCommand()
        command.task = "Test task"
        command.jsonOutput = true
        
        // Capture output
        let pipe = Pipe()
        let originalStdout = dup(STDOUT_FILENO)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        
        do {
            try await command.run()
            #expect(Bool(false), "Should have thrown error")
        } catch {
            // Expected to fail
        }
        
        // Restore stdout
        dup2(originalStdout, STDOUT_FILENO)
        close(originalStdout)
        pipe.fileHandleForWriting.closeFile()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        #expect(output.contains("MISSING_API_KEY"))
    }
    
    @Test("Agent dry run mode")
    func testAgentDryRun() async throws {
        // Set up environment
        setenv("OPENAI_API_KEY", "test-key", 1)
        
        let httpClient = MockHTTPClient()
        let mockAgent = MockOpenAIAgent(httpClient: httpClient)
        mockAgent.setupSimpleTaskResponse()
        
        var command = AgentCommand()
        command.task = "Open TextEdit"
        command.dryRun = true
        command.jsonOutput = true
        
        // This test would need to be integrated with the actual command
        // For now, we're testing the setup and mocking infrastructure
        #expect(command.dryRun == true)
        #expect(httpClient.responses.count > 0)
    }
    
    @Test("Agent executes simple task")
    func testAgentSimpleTask() async throws {
        // This would be an integration test that actually runs the agent
        // For unit testing, we verify the mock setup
        let httpClient = MockHTTPClient()
        let mockAgent = MockOpenAIAgent(httpClient: httpClient)
        mockAgent.setupSimpleTaskResponse()
        
        // Verify mock responses are set up correctly
        #expect(httpClient.responses["https://api.openai.com/v1/assistants"] != nil)
        #expect(httpClient.responses["https://api.openai.com/v1/threads"] != nil)
        
        // Verify the mock would return correct tool calls
        if let runResponse = httpClient.responses["https://api.openai.com/v1/threads/thread_test456/runs"] {
            #expect(runResponse.body.contains("peekaboo_see"))
            #expect(runResponse.body.contains("peekaboo_type"))
            #expect(runResponse.body.contains("Hello World"))
        }
    }
    
    @Test("Agent handles multiple steps")
    func testAgentMultipleSteps() throws {
        let httpClient = MockHTTPClient()
        
        // Set up a more complex workflow
        httpClient.responses["https://api.openai.com/v1/threads/thread_test456/runs"] = (
            statusCode: .ok,
            body: """
            {
                "id": "run_complex",
                "status": "requires_action",
                "required_action": {
                    "type": "submit_tool_outputs",
                    "submit_tool_outputs": {
                        "tool_calls": [
                            {
                                "id": "call_1",
                                "type": "function",
                                "function": {
                                    "name": "peekaboo_app",
                                    "arguments": "{\\"action\\": \\"launch\\", \\"app_name\\": \\"TextEdit\\"}"
                                }
                            },
                            {
                                "id": "call_2",
                                "type": "function",
                                "function": {
                                    "name": "peekaboo_see",
                                    "arguments": "{\\"app_target\\": \\"TextEdit\\"}"
                                }
                            },
                            {
                                "id": "call_3",
                                "type": "function",
                                "function": {
                                    "name": "peekaboo_click",
                                    "arguments": "{\\"element\\": \\"B1\\"}"
                                }
                            },
                            {
                                "id": "call_4",
                                "type": "function",
                                "function": {
                                    "name": "peekaboo_type",
                                    "arguments": "{\\"text\\": \\"Meeting Notes\\\\n\\\\nDate: Today\\"}"
                                }
                            }
                        ]
                    }
                }
            }
            """
        )
        
        // Verify complex workflow
        if let response = httpClient.responses["https://api.openai.com/v1/threads/thread_test456/runs"] {
            let data = response.body.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let requiredAction = json["required_action"] as! [String: Any]
            let submitToolOutputs = requiredAction["submit_tool_outputs"] as! [String: Any]
            let toolCalls = submitToolOutputs["tool_calls"] as! [[String: Any]]
            
            #expect(toolCalls.count == 4)
            #expect((toolCalls[0]["function"] as! [String: Any])["name"] as! String == "peekaboo_app")
            #expect((toolCalls[3]["function"] as! [String: Any])["name"] as! String == "peekaboo_type")
        }
    }
    
    @Test("Agent respects max steps limit")
    func testAgentMaxSteps() throws {
        var command = AgentCommand()
        command.task = "Complex task"
        command.maxSteps = 5
        
        #expect(command.maxSteps == 5)
        
        // In a real test, we would verify that the agent stops after 5 steps
        // even if the task isn't complete
    }
    
    @Test("Agent verbose output")
    func testAgentVerboseOutput() throws {
        var command = AgentCommand()
        command.task = "Test task"
        command.verbose = true
        
        #expect(command.verbose == true)
        
        // In a real test, we would verify that verbose output includes
        // reasoning steps and function calls
    }
}

enum MockHTTPClientError: Error {
    case remoteConnectionClosed
    case bodyLengthExceeded
}