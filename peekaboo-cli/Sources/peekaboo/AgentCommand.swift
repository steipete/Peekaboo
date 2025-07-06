import ArgumentParser
import Foundation

/// AI Agent command that uses OpenAI Assistants API to automate complex tasks
struct AgentCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agent",
        abstract: "Execute complex automation tasks using AI agent",
        discussion: """
        Uses OpenAI Assistants API to break down and execute complex automation tasks.
        The agent can see the screen, interact with UI elements, and verify results.
        
        EXAMPLES:
          peekaboo agent "Open TextEdit and write 'Hello World'"
          peekaboo agent "Take a screenshot of Safari and save it to Desktop"
          peekaboo agent "Click on the login button and fill the form"
          peekaboo "Find the Terminal app and run 'ls -la'" # Direct invocation
        
        The agent will:
        1. Analyze your request
        2. Break it down into steps
        3. Execute each step using Peekaboo commands
        4. Verify results with screenshots
        5. Retry if needed
        """
    )
    
    @Argument(help: "Natural language description of the task to perform")
    var task: String
    
    @Flag(name: .shortAndLong, help: "Enable verbose output showing agent reasoning")
    var verbose = false
    
    @Flag(name: .long, help: "Dry run - show planned steps without executing")
    var dryRun = false
    
    @Option(name: .long, help: "Maximum number of steps the agent can take")
    var maxSteps = 20
    
    @Option(name: .long, help: "OpenAI model to use")
    var model = "gpt-4-turbo"
    
    @Flag(name: .long, help: "Output in JSON format")
    var jsonOutput = false
    
    mutating func run() async throws {
        // Get OpenAI API key
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            if jsonOutput {
                outputAgentJSON(createAgentErrorResponse(.missingAPIKey))
            } else {
                throw AgentError.missingAPIKey
            }
            return
        }
        
        let agent = OpenAIAgent(
            apiKey: apiKey,
            model: model,
            verbose: verbose,
            maxSteps: maxSteps
        )
        
        do {
            if verbose && !jsonOutput {
                print("🤖 Starting agent with task: \(task)")
            }
            
            let result = try await agent.executeTask(task, dryRun: dryRun)
            
            if jsonOutput {
                let response = AgentJSONResponse(
                    success: true,
                    data: result,
                    error: nil
                )
                outputAgentJSON(response)
            } else {
                // Human-readable output
                print("\n✅ Task completed successfully!")
                print("\nSteps executed:")
                for (index, step) in result.steps.enumerated() {
                    print("\n\(index + 1). \(step.description)")
                    if let output = step.output {
                        print("   Result: \(output)")
                    }
                }
                
                if let summary = result.summary {
                    print("\n📝 Summary: \(summary)")
                }
            }
        } catch let error as AgentError {
            if jsonOutput {
                outputAgentJSON(createAgentErrorResponse(error))
            } else {
                throw error
            }
        } catch {
            if jsonOutput {
                outputAgentJSON(createAgentErrorResponse(.apiError(error.localizedDescription)))
            } else {
                throw error
            }
        }
    }
}

// MARK: - OpenAI Agent Implementation

struct OpenAIAgent {
    let apiKey: String
    let model: String
    let verbose: Bool
    let maxSteps: Int
    
    private let session = URLSession.shared
    private let executor = PeekabooCommandExecutor(verbose: false)
    private let retryConfig = RetryConfiguration.default
    
    struct AgentResult: Codable {
        let steps: [Step]
        let summary: String?
        let success: Bool
        
        struct Step: Codable {
            let description: String
            let command: String?
            let output: String?
            let screenshot: String? // Base64 encoded
        }
    }
    
    func executeTask(_ task: String, dryRun: Bool) async throws -> AgentResult {
        // Create session for this task
        let sessionId = await SessionManager.shared.createSession()
        
        // Create assistant
        let assistant = try await createAssistant()
        defer {
            // Clean up assistant
            Task {
                try? await deleteAssistant(assistant.id)
            }
        }
        
        // Create thread
        let thread = try await createThread()
        
        // Add initial message
        try await addMessage(threadId: thread.id, content: task)
        
        // Run the assistant
        var steps: [AgentResult.Step] = []
        var stepCount = 0
        
        while stepCount < maxSteps {
            let run = try await createRun(threadId: thread.id, assistantId: assistant.id)
            
            // Poll for completion
            var runStatus = try await getRun(threadId: thread.id, runId: run.id)
            
            while runStatus.status == "in_progress" || runStatus.status == "queued" {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                runStatus = try await getRun(threadId: thread.id, runId: run.id)
            }
            
            if runStatus.status == "requires_action" {
                // Handle function calls
                guard let toolCalls = runStatus.requiredAction?.submitToolOutputs.toolCalls else {
                    break
                }
                
                var toolOutputs: [(toolCallId: String, output: String)] = []
                
                for toolCall in toolCalls {
                    if verbose && !dryRun {
                        print("🔧 Executing: \(toolCall.function.name) with args: \(toolCall.function.arguments)")
                    }
                    
                    let step = AgentResult.Step(
                        description: toolCall.function.name,
                        command: toolCall.function.arguments,
                        output: nil,
                        screenshot: nil
                    )
                    
                    if !dryRun {
                        // Add session ID to arguments
                        var modifiedArgs = toolCall.function.arguments
                        if let data = modifiedArgs.data(using: .utf8),
                           var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            json["session_id"] = sessionId
                            if let newData = try? JSONSerialization.data(withJSONObject: json),
                               let newString = String(data: newData, encoding: .utf8) {
                                modifiedArgs = newString
                            }
                        }
                        
                        let output = try await executor.executeFunction(
                            name: toolCall.function.name,
                            arguments: modifiedArgs
                        )
                        toolOutputs.append((toolCallId: toolCall.id, output: output))
                    }
                    
                    steps.append(step)
                    stepCount += 1
                }
                
                if !dryRun {
                    // Submit tool outputs
                    try await submitToolOutputs(
                        threadId: thread.id,
                        runId: run.id,
                        toolOutputs: toolOutputs
                    )
                }
            } else if runStatus.status == "completed" {
                // Get the final message
                let messages = try await getMessages(threadId: thread.id)
                let summary = messages.first?.content.first?.text?.value
                
                // Clean up session
                await SessionManager.shared.removeSession(sessionId)
                
                return AgentResult(
                    steps: steps,
                    summary: summary,
                    success: true
                )
            } else {
                throw AgentError.apiError("Assistant run failed with status: \(runStatus.status)")
            }
        }
        
        // Clean up session
        await SessionManager.shared.removeSession(sessionId)
        
        return AgentResult(
            steps: steps,
            summary: "Task completed after \(stepCount) steps",
            success: true
        )
    }
    
    // MARK: - Assistant Management
    
    private func createAssistant() async throws -> Assistant {
        let tools = [
            Self.makePeekabooTool("see", "Capture screenshot and identify UI elements"),
            Self.makePeekabooTool("click", "Click on UI elements or coordinates"),
            Self.makePeekabooTool("type", "Type text into UI elements"),
            Self.makePeekabooTool("scroll", "Scroll content in any direction"),
            Self.makePeekabooTool("hotkey", "Press keyboard shortcuts"),
            Self.makePeekabooTool("image", "Capture screenshots of apps or screen"),
            Self.makePeekabooTool("window", "Manipulate application windows"),
            Self.makePeekabooTool("app", "Control applications (launch, quit, focus)"),
            Self.makePeekabooTool("wait", "Wait for a specified duration")
        ]
        
        let assistantRequest = CreateAssistantRequest(
            model: model,
            name: "Peekaboo Agent",
            description: "An AI agent that can see and interact with macOS UI",
            instructions: """
            You are a helpful AI agent that can see and interact with the macOS desktop.
            You have access to various Peekaboo commands to capture screenshots, click elements, type text, and more.
            
            When given a task:
            1. First use 'see' to capture a screenshot and understand the current state
            2. Break down the task into specific actions
            3. Execute each action using the appropriate Peekaboo command
            4. Verify results with screenshots when needed
            5. Retry if something doesn't work as expected
            
            Always verify the current state before taking actions. Be precise with UI interactions.
            Use the session_id to maintain state across commands.
            """,
            tools: tools
        )
        
        let url = URL(string: "https://api.openai.com/v1/assistants")!
        var request = URLRequest.openAIRequest(url: url, apiKey: apiKey, betaHeader: "assistants=v2")
        try request.setJSONBody(assistantRequest)
        
        return try await session.retryableDataTask(for: request, decodingType: Assistant.self, retryConfig: retryConfig)
    }
    
    private func deleteAssistant(_ assistantId: String) async throws {
        let url = URL(string: "https://api.openai.com/v1/assistants/\(assistantId)")!
        let request = URLRequest.openAIRequest(url: url, method: "DELETE", apiKey: apiKey, betaHeader: "assistants=v2")
        
        _ = try await session.retryableData(for: request, retryConfig: retryConfig)
    }
    
    private func createThread() async throws -> Thread {
        let url = URL(string: "https://api.openai.com/v1/threads")!
        var request = URLRequest.openAIRequest(url: url, apiKey: apiKey, betaHeader: "assistants=v2")
        request.httpBody = "{}".data(using: .utf8)
        
        return try await session.retryableDataTask(for: request, decodingType: Thread.self, retryConfig: retryConfig)
    }
    
    private func addMessage(threadId: String, content: String) async throws {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/messages")!
        var request = URLRequest.openAIRequest(url: url, apiKey: apiKey, betaHeader: "assistants=v2")
        
        let message = ["role": "user", "content": content]
        request.httpBody = try JSONSerialization.data(withJSONObject: message)
        
        _ = try await session.retryableData(for: request, retryConfig: retryConfig)
    }
    
    private func createRun(threadId: String, assistantId: String) async throws -> Run {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/runs")!
        var request = URLRequest.openAIRequest(url: url, apiKey: apiKey, betaHeader: "assistants=v2")
        
        let runData = ["assistant_id": assistantId]
        request.httpBody = try JSONSerialization.data(withJSONObject: runData)
        
        return try await session.retryableDataTask(for: request, decodingType: Run.self, retryConfig: retryConfig)
    }
    
    private func getRun(threadId: String, runId: String) async throws -> Run {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/runs/\(runId)")!
        let request = URLRequest.openAIRequest(url: url, method: "GET", apiKey: apiKey, betaHeader: "assistants=v2")
        
        return try await session.retryableDataTask(for: request, decodingType: Run.self, retryConfig: retryConfig)
    }
    
    private func submitToolOutputs(threadId: String, runId: String, toolOutputs: [(toolCallId: String, output: String)]) async throws {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/runs/\(runId)/submit_tool_outputs")!
        var request = URLRequest.openAIRequest(url: url, apiKey: apiKey, betaHeader: "assistants=v2")
        
        let outputs = toolOutputs.map { ["tool_call_id": $0.toolCallId, "output": $0.output] }
        let data = ["tool_outputs": outputs]
        request.httpBody = try JSONSerialization.data(withJSONObject: data)
        
        _ = try await session.retryableData(for: request, retryConfig: retryConfig)
    }
    
    private func getMessages(threadId: String) async throws -> [Message] {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/messages")!
        let request = URLRequest.openAIRequest(url: url, method: "GET", apiKey: apiKey, betaHeader: "assistants=v2")
        
        let messageList = try await session.retryableDataTask(for: request, decodingType: MessageList.self, retryConfig: retryConfig)
        return messageList.data
    }
}

// MARK: - OpenAI API Types

struct Message: Codable {
    let id: String
    let role: String
    let content: [Content]
    
    struct Content: Codable {
        let type: String
        let text: TextContent?
        
        struct TextContent: Codable {
            let value: String
        }
    }
}

struct MessageList: Codable {
    let data: [Message]
}

struct Assistant: Codable {
    let id: String
    let object: String
    let createdAt: Int
}

struct Thread: Codable {
    let id: String
    let object: String
    let createdAt: Int
}

struct Run: Codable {
    let id: String
    let object: String
    let status: String
    let requiredAction: RequiredAction?
    
    struct RequiredAction: Codable {
        let type: String
        let submitToolOutputs: SubmitToolOutputs
        
        struct SubmitToolOutputs: Codable {
            let toolCalls: [ToolCall]
        }
    }
    
    struct ToolCall: Codable {
        let id: String
        let type: String
        let function: FunctionCall
        
        struct FunctionCall: Codable {
            let name: String
            let arguments: String
        }
    }
}

struct CreateAssistantRequest: Codable {
    let model: String
    let name: String
    let description: String
    let instructions: String
    let tools: [Tool]
}

struct Tool: Codable {
    let type: String
    let function: FunctionDefinition
}