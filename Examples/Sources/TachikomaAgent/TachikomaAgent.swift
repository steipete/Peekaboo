import ArgumentParser
import Foundation
import SharedExampleUtils
import Tachikoma

/// Demonstrate AI agent patterns with function calling using Tachikoma
@main
struct TachikomaAgent: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tachikoma-agent",
        abstract: "🤖 Build AI agents with custom tools and function calling",
        discussion: """
        This example showcases Tachikoma's function calling capabilities, demonstrating how to
        build AI agents that can use custom tools to accomplish complex tasks. The agent can
        call functions for weather, calculations, file operations, and more.

        Examples:
          tachikoma-agent "What's the weather in Tokyo?"
          tachikoma-agent --tools calculator "Calculate 15% tip for $67.50"
          tachikoma-agent --tools weather,file_reader "Check weather and save to file"
          tachikoma-agent --conversation "Start multi-turn conversation"
        """)

    @Argument(help: "The task for the AI agent to perform")
    var task: String?

    @Option(
        name: .shortAndLong,
        help: "Comma-separated list of tools to enable (weather, calculator, file_reader, web_search, all)")
    var tools: String?

    @Option(name: .shortAndLong, help: "Specific provider to use for the agent")
    var provider: String?

    @Flag(name: .shortAndLong, help: "Start conversation mode for multi-turn interactions")
    var conversation: Bool = false

    @Flag(name: .shortAndLong, help: "Show verbose function call details")
    var verbose: Bool = false

    @Flag(name: .long, help: "List available tools and exit")
    var listTools: Bool = false

    @Option(help: "Maximum number of function calls per request")
    var maxFunctionCalls: Int = 5

    func run() async throws {
        TerminalOutput.header("🤖 Tachikoma Agent Demo")

        if self.listTools {
            self.listAvailableTools()
            return
        }

        let modelProvider = try ConfigurationHelper.createProviderWithAvailableModels()
        let availableModels = modelProvider.availableModels()

        if availableModels.isEmpty {
            TerminalOutput.print("❌ No AI providers configured! Please set up API keys.", color: .red)
            ConfigurationHelper.printSetupInstructions()
            return
        }

        // Select tools to enable
        let enabledTools = self.selectTools()

        if self.conversation {
            try await self.runConversationMode(
                modelProvider: modelProvider,
                availableModels: availableModels,
                tools: enabledTools)
        } else {
            guard let task else {
                TerminalOutput.print("❌ Please provide a task or use --conversation mode", color: .red)
                return
            }
            try await self.runSingleTask(
                task: task,
                modelProvider: modelProvider,
                availableModels: availableModels,
                tools: enabledTools)
        }
    }

    /// List available tools
    private func listAvailableTools() {
        TerminalOutput.print("🔧 Available Agent Tools:", color: .cyan)
        TerminalOutput.separator("─")

        for (name, description) in ExampleContent.sampleTools {
            TerminalOutput.print("• \(name): \(description)", color: .white)
        }

        TerminalOutput.separator("─")
        TerminalOutput.print("💡 Use --tools weather,calculator to enable specific tools", color: .yellow)
        TerminalOutput.print("💡 Use --tools all to enable all available tools", color: .yellow)
    }

    /// Select which tools to enable for the agent
    private func selectTools() -> [ToolDefinition] {
        let allTools = self.createAllTools()

        if let toolsString = tools {
            if toolsString.lowercased() == "all" {
                return allTools
            }

            // Parse comma-separated tool names
            let requestedTools = toolsString.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            return allTools.filter { tool in
                requestedTools.contains(tool.function.name.lowercased())
            }
        }

        // Default: enable basic tools for demonstration
        return allTools.filter { ["weather", "calculator"].contains($0.function.name) }
    }

    /// Run a single task
    private func runSingleTask(
        task: String,
        modelProvider: AIModelProvider,
        availableModels: [String],
        tools: [ToolDefinition]) async throws
    {
        let selectedModel = try selectModel(from: availableModels)
        let model = try modelProvider.getModel(selectedModel)
        let providerName = self.getProviderName(from: selectedModel)

        TerminalOutput.print("🎯 Agent Provider: \(providerName)", color: .cyan)
        TerminalOutput.print("🔧 Enabled Tools: \(tools.map(\.function.name).joined(separator: ", "))", color: .dim)
        TerminalOutput.print("💭 Task: \(task)", color: .yellow)
        TerminalOutput.separator("─")

        let agent = AgentRunner(model: model, tools: tools, verbose: verbose, maxFunctionCalls: maxFunctionCalls)
        try await agent.executeTask(task)
    }

    /// Run conversation mode
    private func runConversationMode(
        modelProvider: AIModelProvider,
        availableModels: [String],
        tools: [ToolDefinition]) async throws
    {
        let selectedModel = try selectModel(from: availableModels)
        let model = try modelProvider.getModel(selectedModel)
        let providerName = self.getProviderName(from: selectedModel)

        TerminalOutput.print("🎭 Starting conversation with \(providerName) agent", color: .cyan)
        TerminalOutput.print("🔧 Available tools: \(tools.map(\.function.name).joined(separator: ", "))", color: .dim)
        TerminalOutput.print("Type 'quit' or 'exit' to end the conversation.", color: .dim)
        TerminalOutput.separator("─")

        let agent = AgentRunner(model: model, tools: tools, verbose: verbose, maxFunctionCalls: maxFunctionCalls)

        while true {
            TerminalOutput.print("\n🗣️ You: ", color: .magenta)

            guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else {
                continue
            }

            if input.lowercased() == "quit" || input.lowercased() == "exit" {
                TerminalOutput.print("👋 Goodbye!", color: .green)
                break
            }

            if input.isEmpty {
                continue
            }

            try await agent.continueConversation(input)
        }
    }

    /// Select a model that supports function calling
    private func selectModel(from availableModels: [String]) throws -> String {
        if let requestedProvider = provider {
            let recommended = ProviderDetector.recommendedModels()

            if let recommendedModel = recommended[requestedProvider.capitalized],
               availableModels.contains(recommendedModel)
            {
                return recommendedModel
            }
        }

        // Prefer models with good function calling support
        let functionCallingPreferred = ["gpt-4.1", "claude-opus-4-20250514", "grok-4", "llama3.3"]

        for preferred in functionCallingPreferred {
            if availableModels.contains(preferred) {
                return preferred
            }
        }

        return availableModels.first!
    }

    /// Extract provider name from model name
    private func getProviderName(from modelName: String) -> String {
        switch modelName.lowercased() {
        case let m where m.contains("gpt") || m.contains("o3") || m.contains("o4"):
            "OpenAI"
        case let m where m.contains("claude"):
            "Anthropic"
        case let m where m.contains("llama") || m.contains("llava"):
            "Ollama"
        case let m where m.contains("grok"):
            "Grok"
        default:
            "Unknown"
        }
    }

    /// Create all available tools
    private func createAllTools() -> [ToolDefinition] {
        [
            self.createWeatherTool(),
            self.createCalculatorTool(),
            self.createFileReaderTool(),
            self.createWebSearchTool(),
            self.createTimeTool(),
            self.createRandomTool(),
        ]
    }

    /// Weather lookup tool
    private func createWeatherTool() -> ToolDefinition {
        ToolDefinition(
            function: FunctionDefinition(
                name: "weather",
                description: "Get current weather information for a specific location",
                parameters: ToolParameters.object(properties: [
                    "location": .string(
                        description: "The city and country/state, e.g. 'Tokyo, Japan' or 'San Francisco, CA'"),
                    "units": .string(description: "Temperature units: 'celsius' or 'fahrenheit'"),
                ], required: ["location"])))
    }

    /// Calculator tool
    private func createCalculatorTool() -> ToolDefinition {
        ToolDefinition(
            function: FunctionDefinition(
                name: "calculator",
                description: "Perform mathematical calculations including basic math, percentages, and conversions",
                parameters: ToolParameters.object(properties: [
                    "expression": .string(
                        description: "Mathematical expression to evaluate, e.g. '15 * 0.15' or '67.50 * 1.15'"),
                    "operation": .enumeration(
                        ["basic", "percentage", "tip", "conversion"],
                        description: "Type of calculation"),
                ], required: ["expression"])))
    }

    /// File reader tool
    private func createFileReaderTool() -> ToolDefinition {
        ToolDefinition(
            function: FunctionDefinition(
                name: "file_reader",
                description: "Read contents of text files from the local filesystem",
                parameters: ToolParameters.object(properties: [
                    "file_path": .string(description: "Path to the file to read"),
                    "encoding": .enumeration(["utf8", "ascii"], description: "Text encoding"),
                ], required: ["file_path"])))
    }

    /// Web search tool
    private func createWebSearchTool() -> ToolDefinition {
        ToolDefinition(
            function: FunctionDefinition(
                name: "web_search",
                description: "Search the web for current information (simulated for demo)",
                parameters: ToolParameters.object(properties: [
                    "query": .string(description: "Search query"),
                    "num_results": .integer(description: "Number of results to return (1-10)"),
                ], required: ["query"])))
    }

    /// Time/date tool
    private func createTimeTool() -> ToolDefinition {
        ToolDefinition(
            function: FunctionDefinition(
                name: "time",
                description: "Get current time, date, or timezone information",
                parameters: ToolParameters.object(properties: [
                    "timezone": .string(description: "Timezone identifier, e.g. 'America/New_York' or 'UTC'"),
                    "format": .enumeration(["iso8601", "human", "timestamp"], description: "Output format"),
                ])))
    }

    /// Random number/choice tool
    private func createRandomTool() -> ToolDefinition {
        ToolDefinition(
            function: FunctionDefinition(
                name: "random",
                description: "Generate random numbers or make random choices",
                parameters: ToolParameters.object(properties: [
                    "type": .enumeration(["number", "choice", "dice"], description: "Type of random generation"),
                    "min": .integer(description: "Minimum value for number generation"),
                    "max": .integer(description: "Maximum value for number generation"),
                    "choices": .array(of: .string(), description: "List of choices to pick from"),
                    "sides": .integer(description: "Number of sides for dice roll"),
                ], required: ["type"])))
    }
}

// MARK: - Agent Runner

/// Handles the execution of agent tasks with function calling
class AgentRunner {
    private let model: ModelInterface
    private let tools: [ToolDefinition]
    private let verbose: Bool
    private let maxFunctionCalls: Int
    private var conversationHistory: [Message] = []

    init(model: ModelInterface, tools: [ToolDefinition], verbose: Bool, maxFunctionCalls: Int) {
        self.model = model
        self.tools = tools
        self.verbose = verbose
        self.maxFunctionCalls = maxFunctionCalls
    }

    /// Execute a single task
    func executeTask(_ task: String) async throws {
        self.conversationHistory = [
            Message.system(content: self.createSystemPrompt()),
            Message.user(content: .text(task)),
        ]

        try await self.processConversation()
    }

    /// Continue an ongoing conversation
    func continueConversation(_ userInput: String) async throws {
        self.conversationHistory.append(Message.user(content: .text(userInput)))
        try await self.processConversation()
    }

    /// Process the conversation with function calling
    /// This demonstrates the core agent loop: request -> response -> function calls -> repeat
    private func processConversation() async throws {
        var functionCallCount = 0
        let startTime = Date() // Track total execution time
        var totalTokens = 0 // Track total tokens used across all requests

        while functionCallCount < self.maxFunctionCalls {
            // Create request with conversation history and available tools
            let request = ModelRequest(
                messages: conversationHistory,
                tools: tools.isEmpty ? nil : self.tools, // Include tools for function calling
                settings: ModelSettings(maxTokens: 1000))

            if self.verbose {
                TerminalOutput.print(
                    "📡 Sending request to model... (Function calls: \(functionCallCount)/\(self.maxFunctionCalls))",
                    color: .yellow)
            }

            let response = try await model.getResponse(request: request)

            // Extract text content and tool calls from response
            // AssistantContent can contain both text and function calls
            let textContent = response.content.compactMap { item in
                if case let .outputText(text) = item {
                    return text
                }
                return nil
            }.joined()

            // Track token usage for performance metrics
            totalTokens += PerformanceMeasurement.estimateTokenCount(textContent)

            let toolCalls = response.content.compactMap { item in
                if case let .toolCall(call) = item {
                    return call
                }
                return nil
            }

            // Add assistant message to conversation history
            self.conversationHistory.append(Message.assistant(content: response.content))

            // Check if the model wants to call functions
            if !toolCalls.isEmpty {
                if self.verbose {
                    TerminalOutput.print("🔧 Model requesting \(toolCalls.count) function call(s)", color: .cyan)
                }

                var functionResults: [Message] = []

                // Execute each function call the model requested
                for toolCall in toolCalls {
                    if self.verbose {
                        TerminalOutput.print("  📞 Calling function: \(toolCall.function.name)", color: .yellow)
                        TerminalOutput.print("     Arguments: \(toolCall.function.arguments)", color: .dim)
                    }

                    // Execute the function and get the result
                    let result = try await executeFunction(
                        toolCall.function.name,
                        arguments: toolCall.function.arguments)

                    // Create a tool result message to send back to the model
                    let resultMessage = Message.tool(toolCallId: toolCall.id, content: result)
                    functionResults.append(resultMessage)

                    if self.verbose {
                        TerminalOutput.print("     Result: \(result)", color: .green)
                    }
                }

                // Add all function results to conversation history
                self.conversationHistory.append(contentsOf: functionResults)
                functionCallCount += toolCalls.count

            } else {
                // No function calls, display the response and exit
                let emoji = self.getProviderEmoji()
                TerminalOutput.print("\n\(emoji) Agent: ", color: .bold)

                if !textContent.isEmpty {
                    TerminalOutput.print(textContent, color: .white)
                } else {
                    TerminalOutput.print("(No response content)", color: .dim)
                }

                break
            }
        }

        if functionCallCount >= self.maxFunctionCalls {
            TerminalOutput.print("\n⚠️ Reached maximum function call limit (\(self.maxFunctionCalls))", color: .yellow)
        }

        // Display performance metrics after agent task completion
        let endTime = Date()
        let totalDuration = endTime.timeIntervalSince(startTime)
        self.displayAgentPerformance(
            duration: totalDuration,
            totalTokens: totalTokens,
            functionCalls: functionCallCount)
    }

    /// Execute a function call and return the result
    private func executeFunction(_ functionName: String, arguments: String) async throws -> String {
        switch functionName {
        case "weather":
            try self.executeWeatherFunction(arguments)
        case "calculator":
            try self.executeCalculatorFunction(arguments)
        case "file_reader":
            try self.executeFileReaderFunction(arguments)
        case "web_search":
            try self.executeWebSearchFunction(arguments)
        case "time":
            try self.executeTimeFunction(arguments)
        case "random":
            try self.executeRandomFunction(arguments)
        default:
            "Error: Unknown function '\(functionName)'"
        }
    }

    /// Execute weather function (simulated)
    private func executeWeatherFunction(_ arguments: String) throws -> String {
        // Parse JSON arguments
        let data = arguments.data(using: .utf8) ?? Data()
        let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let args = parsed ?? [:]

        guard let location = args["location"] as? String else {
            return "Error: Missing location parameter"
        }

        let units = args["units"] as? String ?? "celsius"

        // Simulate weather data
        let weatherData = [
            "Tokyo, Japan": ("Partly cloudy", 22, 18),
            "San Francisco, CA": ("Foggy", 15, 12),
            "New York, NY": ("Sunny", 25, 20),
            "London, UK": ("Rainy", 12, 8),
            "Sydney, Australia": ("Clear", 28, 24),
        ]

        if let (condition, highC, lowC) = weatherData[location] {
            if units == "fahrenheit" {
                let highF = Int(Double(highC) * 9 / 5 + 32)
                let lowF = Int(Double(lowC) * 9 / 5 + 32)
                return "Weather in \(location): \(condition), High: \(highF)°F, Low: \(lowF)°F"
            } else {
                return "Weather in \(location): \(condition), High: \(highC)°C, Low: \(lowC)°C"
            }
        } else {
            return "Weather information not available for \(location). Try major cities like Tokyo, San Francisco, New York, London, or Sydney."
        }
    }

    /// Execute calculator function
    private func executeCalculatorFunction(_ arguments: String) throws -> String {
        // Parse JSON arguments
        let data = arguments.data(using: .utf8) ?? Data()
        let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let args = parsed ?? [:]

        guard let expression = args["expression"] as? String else {
            return "Error: Missing expression parameter"
        }

        // Simple expression evaluator (in real implementation, use a proper math parser)
        let result = try evaluateExpression(expression)

        let operation = args["operation"] as? String ?? "basic"

        switch operation {
        case "tip":
            let tipAmount = result
            let total = self.extractNumberFromExpression(expression) + tipAmount
            return String(format: "Tip: $%.2f, Total: $%.2f", tipAmount, total)
        case "percentage":
            return String(format: "%.2f%%", result)
        default:
            return String(format: "%.2f", result)
        }
    }

    /// Execute file reader function
    private func executeFileReaderFunction(_ arguments: String) throws -> String {
        // Parse JSON arguments
        let data = arguments.data(using: .utf8) ?? Data()
        let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let args = parsed ?? [:]

        guard let filePath = args["file_path"] as? String else {
            return "Error: Missing file_path parameter"
        }

        do {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            return "File content (\(content.count) characters):\n\(content)"
        } catch {
            return "Error reading file '\(filePath)': \(error.localizedDescription)"
        }
    }

    /// Execute web search function (simulated)
    private func executeWebSearchFunction(_ arguments: String) throws -> String {
        // Parse JSON arguments
        let data = arguments.data(using: .utf8) ?? Data()
        let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let args = parsed ?? [:]

        guard let query = args["query"] as? String else {
            return "Error: Missing query parameter"
        }

        let numResults = args["num_results"] as? Int ?? 3

        // Simulate search results
        return """
        Search results for "\(query)" (\(numResults) results):

        1. Example.com - Comprehensive guide to \(query)
           Summary: Detailed information about \(query) with practical examples...

        2. Reference.org - \(query) documentation
           Summary: Official documentation and API reference for \(query)...

        3. Tutorial.net - Learn \(query) step by step
           Summary: Beginner-friendly tutorial covering the basics of \(query)...

        Note: This is a simulated search. In a real implementation, this would use a web search API.
        """
    }

    /// Execute time function
    private func executeTimeFunction(_ arguments: String) throws -> String {
        // Parse JSON arguments
        let data = arguments.data(using: .utf8) ?? Data()
        let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let args = parsed ?? [:]

        let timezone = args["timezone"] as? String ?? "UTC"
        let format = args["format"] as? String ?? "human"

        let now = Date()
        let formatter = DateFormatter()

        // Set timezone
        if let tz = TimeZone(identifier: timezone) {
            formatter.timeZone = tz
        }

        switch format {
        case "iso8601":
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            return formatter.string(from: now)
        case "timestamp":
            return String(Int(now.timeIntervalSince1970))
        default: // human
            formatter.dateStyle = .full
            formatter.timeStyle = .full
            return formatter.string(from: now)
        }
    }

    /// Execute random function
    private func executeRandomFunction(_ arguments: String) throws -> String {
        // Parse JSON arguments
        let data = arguments.data(using: .utf8) ?? Data()
        let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let args = parsed ?? [:]

        guard let type = args["type"] as? String else {
            return "Error: Missing type parameter"
        }

        switch type {
        case "number":
            let min = args["min"] as? Int ?? 1
            let max = args["max"] as? Int ?? 100
            let result = Int.random(in: min...max)
            return "Random number between \(min) and \(max): \(result)"

        case "choice":
            guard let choicesArray = args["choices"] as? [String],
                  !choicesArray.isEmpty
            else {
                return "Error: No choices provided"
            }
            let result = choicesArray.randomElement()!
            return "Random choice from [\(choicesArray.joined(separator: ", "))]: \(result)"

        case "dice":
            let sides = args["sides"] as? Int ?? 6
            let result = Int.random(in: 1...sides)
            return "Rolled \(sides)-sided die: \(result)"

        default:
            return "Error: Unknown random type '\(type)'"
        }
    }

    /// Simple expression evaluator
    private func evaluateExpression(_ expression: String) throws -> Double {
        // This is a very basic evaluator - in a real implementation, use NSExpression or a proper parser
        let cleanExpression = expression.replacingOccurrences(of: " ", with: "")

        // Handle simple operations
        if cleanExpression.contains("*") {
            let parts = cleanExpression.split(separator: "*")
            if parts.count == 2,
               let left = Double(parts[0]),
               let right = Double(parts[1])
            {
                return left * right
            }
        }

        if cleanExpression.contains("/") {
            let parts = cleanExpression.split(separator: "/")
            if parts.count == 2,
               let left = Double(parts[0]),
               let right = Double(parts[1])
            {
                return left / right
            }
        }

        if cleanExpression.contains("+") {
            let parts = cleanExpression.split(separator: "+")
            if parts.count == 2,
               let left = Double(parts[0]),
               let right = Double(parts[1])
            {
                return left + right
            }
        }

        if cleanExpression.contains("-") {
            let parts = cleanExpression.split(separator: "-")
            if parts.count == 2,
               let left = Double(parts[0]),
               let right = Double(parts[1])
            {
                return left - right
            }
        }

        // Try to parse as a single number
        if let number = Double(cleanExpression) {
            return number
        }

        throw NSError(domain: "Calculator", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Unable to evaluate expression: \(expression)",
        ])
    }

    /// Extract base number from expression for tip calculations
    private func extractNumberFromExpression(_ expression: String) -> Double {
        let components = expression.split(whereSeparator: { "+-*/".contains($0) })
        if let first = components.first, let number = Double(first) {
            return number
        }
        return 0
    }

    /// Create system prompt for the agent
    private func createSystemPrompt() -> String {
        let toolNames = self.tools.map(\.function.name).joined(separator: ", ")

        return """
        You are a helpful AI agent with access to the following tools: \(toolNames).

        Use these tools to help the user accomplish their tasks. Always:
        1. Use appropriate tools when the task requires external information or computation
        2. Provide clear, helpful responses
        3. Explain what you're doing when calling functions
        4. Be conversational and friendly

        Available tools:
        \(self.tools.map { "- \($0.function.name): \($0.function.description)" }.joined(separator: "\n"))

        When a user asks for something that can be accomplished with your tools, use them!
        """
    }

    /// Get provider emoji for display
    private func getProviderEmoji() -> String {
        // This is a simple implementation - in practice, you'd detect from the model
        "🤖"
    }

    /// Display agent performance metrics after task completion
    private func displayAgentPerformance(duration: TimeInterval, totalTokens: Int, functionCalls: Int) {
        TerminalOutput.separator("─")
        TerminalOutput.print("📊 Agent Performance Summary:", color: .bold)

        let stats = [
            "⏱️ Total time: \(String(format: "%.2fs", duration))",
            "🔤 Tokens used: ~\(totalTokens)",
            "🔧 Function calls: \(functionCalls)",
        ]

        TerminalOutput.print(stats.joined(separator: " | "), color: .dim)

        // Performance assessment
        if duration < 10 {
            TerminalOutput.print("🚀 Performance: Fast", color: .green)
        } else if duration < 30 {
            TerminalOutput.print("⚡ Performance: Good", color: .yellow)
        } else {
            TerminalOutput.print("🐌 Performance: Slow (complex task or model latency)", color: .yellow)
        }

        TerminalOutput.separator("─")
    }
}
