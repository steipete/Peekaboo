import Foundation
import os.log

@available(macOS 13.0, *)
actor OpenAIAgent {
    private let apiKey: String
    private let model: String
    private let verbose: Bool
    private let maxSteps: Int
    private let session: URLSession
    private let logger = Logger(subsystem: "com.steipete.peekaboo", category: "OpenAIAgent")

    // Tool executor protocol - to be implemented by the app
    let toolExecutor: ToolExecutor
    
    // Event delegate for real-time updates
    weak var eventDelegate: AgentEventDelegate?

    init(
        apiKey: String,
        model: String = "gpt-4-turbo",
        verbose: Bool = false,
        maxSteps: Int = 20,
        toolExecutor: ToolExecutor,
        eventDelegate: AgentEventDelegate? = nil)
    {
        self.apiKey = apiKey
        self.model = model
        self.verbose = verbose
        self.maxSteps = maxSteps
        self.session = URLSession.shared
        self.toolExecutor = toolExecutor
        self.eventDelegate = eventDelegate
    }

    // MARK: - Public Methods

    func executeTask(_ task: String, dryRun: Bool = false) async throws -> AgentResult {
        self.logger.info("Starting task: \(task)")
        
        // Emit started event
        await self.emitEvent(.started)

        // Create assistant
        let assistant = try await createAssistant()
        if self.verbose {
            self.logger.info("Assistant created: \(assistant.id)")
        }

        // Create thread
        let thread = try await createThread()
        if self.verbose {
            self.logger.info("Thread created: \(thread.id)")
        }

        // Store IDs for cleanup
        let assistantId = assistant.id
        let threadId = thread.id

        defer {
            // Clean up assistant and thread
            Task {
                try? await deleteAssistant(assistantId)
                try? await deleteThread(threadId)
            }
        }

        // Add initial message
        try await self.addMessage(threadId: threadId, content: task)

        // Run the assistant
        var outputs: [String] = []
        var stepCount = 0

        // Create initial run
        let run = try await createRun(threadId: threadId, assistantId: assistant.id)

        // Process the run until it's completed or we hit max steps
        while stepCount < self.maxSteps {
            var runStatus = try await getRun(threadId: threadId, runId: run.id)

            // Wait while in progress
            var pollCount = 0
            while runStatus.status == .inProgress || runStatus.status == .queued {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                runStatus = try await self.getRun(threadId: threadId, runId: run.id)
                pollCount += 1

                if pollCount > 60 { // 60 second timeout
                    throw AgentError.timeout
                }
            }

            switch runStatus.status {
            case .requiresAction:
                // Handle function calls
                guard let toolCalls = runStatus.requiredAction?.submitToolOutputs.toolCalls else {
                    break
                }

                var toolOutputs: [(toolCallId: String, output: String)] = []

                for toolCall in toolCalls {
                    if self.verbose {
                        self.logger.info("Executing tool: \(toolCall.function.name)")
                    }
                    
                    // Emit tool call started event
                    await self.emitEvent(.toolCallStarted(name: toolCall.function.name, arguments: toolCall.function.arguments))

                    let output: String = if dryRun {
                        "[DRY RUN] Would execute: \(toolCall.function.name)"
                    } else {
                        await self.toolExecutor.executeTool(
                            name: toolCall.function.name,
                            arguments: toolCall.function.arguments)
                    }

                    outputs.append("\(toolCall.function.name): \(output)")
                    stepCount += 1

                    toolOutputs.append((toolCallId: toolCall.id, output: output))
                    
                    // Emit tool call completed event
                    await self.emitEvent(.toolCallCompleted(name: toolCall.function.name, result: output))
                }

                // Submit tool outputs
                try await self.submitToolOutputs(threadId: threadId, runId: run.id, toolOutputs: toolOutputs)

            case .completed:
                // Get final message
                let messages = try await getMessages(threadId: threadId)
                let assistantMessages = messages.filter { $0.role == "assistant" }

                let summary = assistantMessages.last?.content.first?.text?.value
                
                // Emit assistant message if we have one
                if let finalMessage = summary {
                    await self.emitEvent(.assistantMessage(content: finalMessage))
                }
                
                // Emit completed event
                await self.emitEvent(.completed)

                return AgentResult(
                    success: true,
                    output: summary ?? outputs.joined(separator: "\n"),
                    error: nil)

            case .failed, .cancelled, .expired:
                let errorMessage = "Run ended with status: \(runStatus.status)"
                await self.emitEvent(.error(message: errorMessage))
                throw AgentError.commandFailed(errorMessage)

            default:
                break
            }
        }

        throw AgentError.commandFailed("Exceeded maximum steps (\(self.maxSteps))")
    }

    // MARK: - Event Handling
    
    private func emitEvent(_ event: AgentEvent) async {
        guard let delegate = eventDelegate else { return }
        
        // Call delegate on a detached task to avoid actor isolation issues
        Task.detached { @MainActor in
            delegate.agentDidEmitEvent(event)
        }
    }
    
    // MARK: - Private Methods

    private func createAssistant() async throws -> Assistant {
        let tools = self.toolExecutor.availableTools()

        let assistantRequest = AssistantRequest(
            model: model,
            name: "Peekaboo Agent",
            description: "AI agent for macOS automation",
            instructions: toolExecutor.systemPrompt(),
            tools: tools)

        let url = URL(string: "https://api.openai.com/v1/assistants")!
        var request = self.createOpenAIRequest(url: url, method: "POST")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
        request.httpBody = try JSONEncoder().encode(assistantRequest)

        return try await self.performRequest(request, decodingType: Assistant.self)
    }

    private func deleteAssistant(_ assistantId: String) async throws {
        let url = URL(string: "https://api.openai.com/v1/assistants/\(assistantId)")!
        var request = self.createOpenAIRequest(url: url, method: "DELETE")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
        _ = try await self.session.data(for: request)
    }

    private func deleteThread(_ threadId: String) async throws {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)")!
        var request = self.createOpenAIRequest(url: url, method: "DELETE")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
        _ = try await self.session.data(for: request)
    }

    private func createThread() async throws -> Thread {
        let url = URL(string: "https://api.openai.com/v1/threads")!
        var request = self.createOpenAIRequest(url: url, method: "POST")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
        request.httpBody = "{}".data(using: .utf8)

        return try await self.performRequest(request, decodingType: Thread.self)
    }

    private func addMessage(threadId: String, content: String) async throws {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/messages")!
        var request = self.createOpenAIRequest(url: url, method: "POST")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

        let message = ["role": "user", "content": content]
        request.httpBody = try JSONSerialization.data(withJSONObject: message)

        _ = try await self.session.data(for: request)
    }

    private func createRun(threadId: String, assistantId: String) async throws -> Run {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/runs")!
        var request = self.createOpenAIRequest(url: url, method: "POST")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

        let runData = ["assistant_id": assistantId]
        request.httpBody = try JSONSerialization.data(withJSONObject: runData)

        return try await self.performRequest(request, decodingType: Run.self)
    }

    private func getRun(threadId: String, runId: String) async throws -> Run {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/runs/\(runId)")!
        var request = self.createOpenAIRequest(url: url, method: "GET")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

        return try await self.performRequest(request, decodingType: Run.self)
    }

    private func submitToolOutputs(
        threadId: String,
        runId: String,
        toolOutputs: [(toolCallId: String, output: String)]) async throws
    {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/runs/\(runId)/submit_tool_outputs")!
        var request = self.createOpenAIRequest(url: url, method: "POST")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

        let outputs = toolOutputs.map { ["tool_call_id": $0.toolCallId, "output": $0.output] }
        let data = ["tool_outputs": outputs]
        request.httpBody = try JSONSerialization.data(withJSONObject: data)

        _ = try await self.session.data(for: request)
    }

    private func getMessages(threadId: String) async throws -> [Message] {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/messages")!
        var request = self.createOpenAIRequest(url: url, method: "GET")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

        let messageList = try await performRequest(request, decodingType: MessageList.self)
        return messageList.data
    }

    // MARK: - Helper Methods

    private func createOpenAIRequest(url: URL, method: String = "POST") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func performRequest<T: Decodable>(_ request: URLRequest, decodingType _: T.Type) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentError.invalidResponse("Not an HTTP response")
        }

        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)

        case 401:
            throw AgentError.apiError("Invalid API key")

        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { Double($0) }
            throw AgentError.rateLimited(retryAfter: retryAfter)

        default:
            if let errorData = try? JSONDecoder().decode(OpenAIError.self, from: data) {
                throw AgentError.apiError(errorData.error.message)
            }
            throw AgentError.apiError("HTTP \(httpResponse.statusCode)")
        }
    }
}
