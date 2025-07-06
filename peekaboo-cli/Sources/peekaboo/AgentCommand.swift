import ArgumentParser
import Foundation
import AsyncHTTPClient
import NIOCore
import NIOHTTP1

/// Agentic command that uses OpenAI Assistants API to automate complex tasks
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
        // Initialize HTTP client
        let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
        defer {
            try? httpClient.syncShutdown()
        }
        
        // Get OpenAI API key
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            if jsonOutput {
                let output = JSONOutput(
                    success: false,
                    error: ErrorResponse(
                        code: "MISSING_API_KEY",
                        message: "OpenAI API key not found. Set OPENAI_API_KEY environment variable.",
                        details: nil
                    )
                )
                try outputJSON(output)
                return
            } else {
                throw ValidationError("OpenAI API key not found. Set OPENAI_API_KEY environment variable.")
            }
        }
        
        let agent = OpenAIAgent(
            apiKey: apiKey,
            model: model,
            httpClient: httpClient,
            verbose: verbose,
            maxSteps: maxSteps
        )
        
        do {
            if verbose && !jsonOutput {
                print("🤖 Starting agent with task: \(task)")
            }
            
            let result = try await agent.executeTask(task, dryRun: dryRun)
            
            if jsonOutput {
                let output = JSONOutput(
                    success: true,
                    data: result,
                    error: nil
                )
                try outputJSON(output)
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
        } catch {
            if jsonOutput {
                let output = JSONOutput(
                    success: false,
                    error: ErrorResponse(
                        code: "AGENT_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    )
                )
                try outputJSON(output)
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
    let httpClient: HTTPClient
    let verbose: Bool
    let maxSteps: Int
    
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
        // Create assistant
        let assistant = try await createAssistant()
        defer {
            // Clean up assistant
            // Cleanup handled later
            _ = assistant
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
                        let output = try await executeFunction(
                            name: toolCall.function.name,
                            arguments: toolCall.function.arguments
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
                let summary = messages.first?.content.first?.text.value
                
                return AgentResult(
                    steps: steps,
                    summary: summary,
                    success: true
                )
            } else {
                throw ValidationError("Assistant run failed with status: \(runStatus.status)")
            }
        }
        
        return AgentResult(
            steps: steps,
            summary: "Task completed after \(stepCount) steps",
            success: true
        )
    }
    
    // MARK: - Assistant Management
    
    private func createAssistant() async throws -> Assistant {
        let tools = [
            makePeekabooTool("see", "Capture screenshot and identify UI elements"),
            makePeekabooTool("click", "Click on UI elements or coordinates"),
            makePeekabooTool("type", "Type text into UI elements"),
            makePeekabooTool("scroll", "Scroll content in any direction"),
            makePeekabooTool("hotkey", "Press keyboard shortcuts"),
            makePeekabooTool("image", "Capture screenshots of apps or screen"),
            makePeekabooTool("window", "Manipulate application windows"),
            makePeekabooTool("menu", "Interact with application menus"),
            makePeekabooTool("app", "Control applications (launch, quit, focus)")
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
            """,
            tools: tools
        )
        
        let url = URL(string: "https://api.openai.com/v1/assistants")!
        var request = HTTPClientRequest(url: url.absoluteString)
        request.method = .POST
        request.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        request.headers.add(name: "Content-Type", value: "application/json")
        request.headers.add(name: "OpenAI-Beta", value: "assistants=v2")
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.body = .bytes(ByteBuffer(data: try encoder.encode(assistantRequest)))
        
        let response = try await httpClient.execute(request, timeout: .seconds(30))
        var body = ByteBuffer()
        for try await chunk in response.body {
            body.writeImmutableBuffer(chunk)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Assistant.self, from: Data(buffer: body))
    }
    
    private func makePeekabooTool(_ name: String, _ description: String) -> Tool {
        // Create function definition for each Peekaboo command
        let parameters: [String: Any] = {
            switch name {
            case "see":
                return [
                    "type": "object",
                    "properties": [
                        "app_target": ["type": "string", "description": "Application name or 'frontmost'"],
                        "window_title": ["type": "string", "description": "Specific window title"],
                        "session_id": ["type": "string", "description": "Session ID for tracking state"]
                    ]
                ]
            case "click":
                return [
                    "type": "object",
                    "properties": [
                        "element": ["type": "string", "description": "Element ID (e.g., 'B1') or query"],
                        "x": ["type": "number", "description": "X coordinate"],
                        "y": ["type": "number", "description": "Y coordinate"],
                        "double_click": ["type": "boolean", "description": "Perform double click"]
                    ]
                ]
            case "type":
                return [
                    "type": "object",
                    "properties": [
                        "text": ["type": "string", "description": "Text to type"],
                        "element": ["type": "string", "description": "Target element ID or query"],
                        "clear_first": ["type": "boolean", "description": "Clear existing text first"]
                    ],
                    "required": ["text"]
                ]
            default:
                return ["type": "object", "properties": [:]]
            }
        }()
        
        return Tool(
            type: "function",
            function: FunctionDefinition(
                name: "peekaboo_\(name)",
                description: description,
                parameters: parameters
            )
        )
    }
    
    private func executeFunction(name: String, arguments: String) async throws -> String {
        // Parse the function name and arguments
        let commandName = name.replacingOccurrences(of: "peekaboo_", with: "")
        
        // Parse JSON arguments
        guard let argsData = arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] else {
            return "{\"success\": false, \"error\": {\"code\": \"INVALID_ARGS\", \"message\": \"Failed to parse arguments\"}}"
        }
        
        // Get the path to the current executable
        let executablePath = CommandLine.arguments[0]
        
        // Build command line arguments
        var cliArgs = [commandName, "--json-output"]
        
        // Add arguments based on command
        switch commandName {
        case "see":
            if let app = args["app_target"] as? String {
                cliArgs.append("--app")
                cliArgs.append(app)
            }
            if let title = args["window_title"] as? String {
                cliArgs.append("--window-title")
                cliArgs.append(title)
            }
            if let sessionId = args["session_id"] as? String {
                cliArgs.append("--session-id")
                cliArgs.append(sessionId)
            }
            
        case "click":
            if let element = args["element"] as? String {
                cliArgs.append("--element")
                cliArgs.append(element)
            } else if let x = args["x"] as? Double, let y = args["y"] as? Double {
                cliArgs.append("--coordinates")
                cliArgs.append("\(Int(x)),\(Int(y))")
            }
            if let doubleClick = args["double_click"] as? Bool, doubleClick {
                cliArgs.append("--double-click")
            }
            
        case "type":
            if let text = args["text"] as? String {
                cliArgs.append(text)
            }
            if let element = args["element"] as? String {
                cliArgs.append("--element")
                cliArgs.append(element)
            }
            if let clearFirst = args["clear_first"] as? Bool, clearFirst {
                cliArgs.append("--clear-first")
            }
            
        case "scroll":
            if let direction = args["direction"] as? String {
                cliArgs.append("--direction")
                cliArgs.append(direction)
            }
            if let amount = args["amount"] as? Int {
                cliArgs.append("--amount")
                cliArgs.append(String(amount))
            }
            
        case "hotkey":
            if let keys = args["keys"] as? [String] {
                cliArgs.append(contentsOf: keys)
            }
            
        case "image":
            if let app = args["app"] as? String {
                cliArgs.append("--app")
                cliArgs.append(app)
            }
            if let mode = args["mode"] as? String {
                cliArgs.append("--mode")
                cliArgs.append(mode)
            }
            // Return base64 data for agent to see
            cliArgs.append("--format")
            cliArgs.append("data")
            
        case "window":
            if let action = args["action"] as? String {
                cliArgs.append(action)
            }
            if let app = args["app"] as? String {
                cliArgs.append("--app")
                cliArgs.append(app)
            }
            
        case "app":
            if let action = args["action"] as? String {
                cliArgs.append(action)
            }
            if let appName = args["app_name"] as? String {
                cliArgs.append(appName)
            }
            
        default:
            // For commands we haven't mapped yet
            for (key, value) in args {
                cliArgs.append("--\(key.replacingOccurrences(of: "_", with: "-"))")
                cliArgs.append(String(describing: value))
            }
        }
        
        // Execute the command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = cliArgs
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        var output = String(data: outputData, encoding: .utf8) ?? ""
        
        // If there's no output, check stderr
        if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            output = String(data: errorData, encoding: .utf8) ?? ""
        }
        
        // If the process failed, wrap in error JSON
        if process.terminationStatus != 0 && !output.contains("\"success\"") {
            let errorMessage = output.isEmpty ? "Command failed with exit code \(process.terminationStatus)" : output
            output = """
            {
                "success": false,
                "error": {
                    "code": "COMMAND_FAILED",
                    "message": \(errorMessage.debugDescription)
                }
            }
            """
        }
        
        return output
    }
    
    // MARK: - API Methods
    
    private func deleteAssistant(_ assistantId: String) async throws {
        let url = URL(string: "https://api.openai.com/v1/assistants/\(assistantId)")!
        var request = HTTPClientRequest(url: url.absoluteString)
        request.method = .DELETE
        request.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        request.headers.add(name: "OpenAI-Beta", value: "assistants=v2")
        
        _ = try await httpClient.execute(request, timeout: .seconds(30))
    }
    
    private func createThread() async throws -> Thread {
        let url = URL(string: "https://api.openai.com/v1/threads")!
        var request = HTTPClientRequest(url: url.absoluteString)
        request.method = .POST
        request.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        request.headers.add(name: "Content-Type", value: "application/json")
        request.headers.add(name: "OpenAI-Beta", value: "assistants=v2")
        request.body = .bytes(ByteBuffer(string: "{}"))
        
        let response = try await httpClient.execute(request, timeout: .seconds(30))
        var body = ByteBuffer()
        for try await chunk in response.body {
            body.writeImmutableBuffer(chunk)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Thread.self, from: Data(buffer: body))
    }
    
    private func addMessage(threadId: String, content: String) async throws {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/messages")!
        var request = HTTPClientRequest(url: url.absoluteString)
        request.method = .POST
        request.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        request.headers.add(name: "Content-Type", value: "application/json")
        request.headers.add(name: "OpenAI-Beta", value: "assistants=v2")
        
        let message = ["role": "user", "content": content]
        let jsonData = try JSONSerialization.data(withJSONObject: message)
        request.body = .bytes(ByteBuffer(data: jsonData))
        
        _ = try await httpClient.execute(request, timeout: .seconds(30))
    }
    
    private func createRun(threadId: String, assistantId: String) async throws -> Run {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/runs")!
        var request = HTTPClientRequest(url: url.absoluteString)
        request.method = .POST
        request.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        request.headers.add(name: "Content-Type", value: "application/json")
        request.headers.add(name: "OpenAI-Beta", value: "assistants=v2")
        
        let runData = ["assistant_id": assistantId]
        let jsonData = try JSONSerialization.data(withJSONObject: runData)
        request.body = .bytes(ByteBuffer(data: jsonData))
        
        let response = try await httpClient.execute(request, timeout: .seconds(30))
        var body = ByteBuffer()
        for try await chunk in response.body {
            body.writeImmutableBuffer(chunk)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Run.self, from: Data(buffer: body))
    }
    
    private func getRun(threadId: String, runId: String) async throws -> Run {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/runs/\(runId)")!
        var request = HTTPClientRequest(url: url.absoluteString)
        request.method = .GET
        request.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        request.headers.add(name: "OpenAI-Beta", value: "assistants=v2")
        
        let response = try await httpClient.execute(request, timeout: .seconds(30))
        var body = ByteBuffer()
        for try await chunk in response.body {
            body.writeImmutableBuffer(chunk)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Run.self, from: Data(buffer: body))
    }
    
    private func submitToolOutputs(threadId: String, runId: String, toolOutputs: [(toolCallId: String, output: String)]) async throws {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/runs/\(runId)/submit_tool_outputs")!
        var request = HTTPClientRequest(url: url.absoluteString)
        request.method = .POST
        request.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        request.headers.add(name: "Content-Type", value: "application/json")
        request.headers.add(name: "OpenAI-Beta", value: "assistants=v2")
        
        let outputs = toolOutputs.map { ["tool_call_id": $0.toolCallId, "output": $0.output] }
        let data = ["tool_outputs": outputs]
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        request.body = .bytes(ByteBuffer(data: jsonData))
        
        _ = try await httpClient.execute(request, timeout: .seconds(30))
    }
    
    private func getMessages(threadId: String) async throws -> [Message] {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/messages")!
        var request = HTTPClientRequest(url: url.absoluteString)
        request.method = .GET
        request.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        request.headers.add(name: "OpenAI-Beta", value: "assistants=v2")
        
        let response = try await httpClient.execute(request, timeout: .seconds(30))
        var body = ByteBuffer()
        for try await chunk in response.body {
            body.writeImmutableBuffer(chunk)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let messageList = try decoder.decode(MessageList.self, from: Data(buffer: body))
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

struct FunctionDefinition: Codable {
    let name: String
    let description: String
    let parameters: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case name, description, parameters
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        let parametersData = try JSONSerialization.data(withJSONObject: parameters)
        try container.encode(parametersData, forKey: .parameters)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        let parametersData = try container.decode(Data.self, forKey: .parameters)
        parameters = try JSONSerialization.jsonObject(with: parametersData) as? [String: Any] ?? [:]
    }
    
    init(name: String, description: String, parameters: [String: Any]) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}