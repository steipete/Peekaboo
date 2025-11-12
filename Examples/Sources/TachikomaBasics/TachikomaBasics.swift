import Commander
import Foundation
import SharedExampleUtils
import Tachikoma

/// Simple getting started example demonstrating basic Tachikoma usage
@main
struct TachikomaBasics: AsyncParsableCommand {
    static let commandDescription = CommandDescription(
        commandName: "tachikoma-basics",
        abstract: "🎓 Learn the basics of using Tachikoma for AI interactions",
        discussion: """
        This example demonstrates the fundamental concepts of using Tachikoma:
        - Setting up AI model providers
        - Making basic requests
        - Handling responses and errors
        - Provider-agnostic code patterns

        Examples:
          tachikoma-basics "Hello, AI!"
          tachikoma-basics --provider openai "Write a haiku"
          tachikoma-basics --list-providers
        """)

    @Argument(help: "The message to send to the AI")
    var message: String?

    @Option(name: .shortAndLong, help: "Specific provider to use (openai, anthropic, ollama, grok)")
    var provider: String?

    @Flag(name: .long, help: "List all available providers and exit")
    var listProviders: Bool = false

    @Flag(name: .shortAndLong, help: "Show detailed information about the process")
    var verbose: Bool = false

    func run() async throws {
        TerminalOutput.header("🎓 Tachikoma Basics")

        if self.listProviders {
            try self.listAvailableProviders()
            return
        }

        guard let message else {
            TerminalOutput.print("❌ Please provide a message or use --list-providers", color: .red)
            return
        }

        try await self.demonstrateBasicUsage(message: message)
    }

    /// List available providers and their status
    private func listAvailableProviders() throws {
        TerminalOutput.print("🔍 Scanning for available AI providers...\n", color: .cyan)

        // Show environment-based detection
        let detectedProviders = ProviderDetector.detectAvailableProviders()
        TerminalOutput.print("Detected providers: \(detectedProviders.joined(separator: ", "))", color: .green)

        // Try to create the model provider
        do {
            let modelProvider = try AIConfiguration.fromEnvironment()
            let availableModels = modelProvider.availableModels()

            TerminalOutput.print("\n📋 Available models (\(availableModels.count) total):", color: .bold)

            let groupedModels = self.groupModelsByProvider(availableModels)
            for (provider, models) in groupedModels.sorted(by: { $0.key < $1.key }) {
                TerminalOutput.providerHeader(provider)
                for model in models.sorted() {
                    TerminalOutput.print("  • \(model)", color: .white)
                }
                print("")
            }

        } catch {
            TerminalOutput.print("❌ Failed to initialize providers: \(error)", color: .red)
            ConfigurationHelper.printSetupInstructions()
        }
    }

    /// Group models by their provider
    private func groupModelsByProvider(_ models: [String]) -> [String: [String]] {
        var grouped: [String: [String]] = [:]

        for model in models {
            let provider = self.detectProviderFromModel(model)
            if grouped[provider] == nil {
                grouped[provider] = []
            }
            grouped[provider]?.append(model)
        }

        return grouped
    }

    /// Detect provider name from model string
    private func detectProviderFromModel(_ model: String) -> String {
        let lowercased = model.lowercased()
        if lowercased.contains("gpt") || lowercased.contains("o3") || lowercased.contains("o4") {
            return "OpenAI"
        } else if lowercased.contains("claude") {
            return "Anthropic"
        } else if lowercased.contains("llama") || lowercased.contains("llava") {
            return "Ollama"
        } else if lowercased.contains("grok") {
            return "Grok"
        } else {
            return "Unknown"
        }
    }

    /// Demonstrate basic Tachikoma usage patterns
    private func demonstrateBasicUsage(message: String) async throws {
        if self.verbose {
            TerminalOutput.print("🔧 Setting up Tachikoma...", color: .yellow)
        }

        // Step 1: Create the model provider
        // AIConfiguration.fromEnvironment() automatically detects API keys and sets up providers
        let modelProvider: AIModelProvider
        do {
            modelProvider = try AIConfiguration.fromEnvironment()
            if self.verbose {
                TerminalOutput.print("✅ Successfully initialized AIModelProvider", color: .green)
            }
        } catch {
            TerminalOutput.print("❌ Failed to set up providers: \(error)", color: .red)
            TerminalOutput.print("\n💡 Make sure you have API keys configured:", color: .yellow)
            ConfigurationHelper.printSetupInstructions()
            return
        }

        // Step 2: Select which model to use
        // This demonstrates Tachikoma's provider-agnostic approach
        let selectedModel = try selectModel(from: modelProvider)

        if self.verbose {
            TerminalOutput.print("🎯 Selected model: \(selectedModel)", color: .cyan)
        }

        // Step 3: Get the model instance
        // Same interface works for OpenAI, Anthropic, Ollama, or Grok
        let model = try modelProvider.getModel(selectedModel)

        if self.verbose {
            TerminalOutput.print("📡 Creating request...", color: .yellow)
        }

        // Step 4: Create a request
        // ModelRequest provides a unified interface across all providers
        let request = ModelRequest(
            messages: [Message.user(content: .text(message))], // Simple text message
            tools: nil, // No function calling for this basic example
            settings: ModelSettings(maxTokens: 300), // Limit response length
        )

        if self.verbose {
            TerminalOutput.print(
                "🚀 Sending request to \(self.detectProviderFromModel(selectedModel))...",
                color: .yellow)
        }

        // Step 5: Send the request and measure performance
        let startTime = Date()
        do {
            // The same getResponse() call works with any provider
            let response = try await model.getResponse(request: request)
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)

            // Display the results
            self.displayResponse(
                message: message,
                response: response,
                model: selectedModel,
                duration: duration)

        } catch {
            TerminalOutput.print("❌ Request failed: \(error)", color: .red)

            if self.verbose {
                TerminalOutput.print("\n🔍 Debugging information:", color: .yellow)
                TerminalOutput.print("Model: \(selectedModel)", color: .dim)
                TerminalOutput.print("Error type: \(type(of: error))", color: .dim)
            }
        }
    }

    /// Select a model based on user preference or auto-detection
    private func selectModel(from modelProvider: AIModelProvider) throws -> String {
        let availableModels = modelProvider.availableModels()

        if availableModels.isEmpty {
            throw NSError(domain: "TachikomaBasics", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No models available. Please configure API keys.",
            ])
        }

        // If user specified a provider, find the best model for it
        if let requestedProvider = provider {
            let recommended = ProviderDetector.recommendedModels()

            // Try to use the recommended model for this provider
            if let recommendedModel = recommended[requestedProvider.capitalized],
               availableModels.contains(recommendedModel)
            {
                return recommendedModel
            } else {
                // Find any model from the requested provider
                let providerModels = availableModels.filter { model in
                    self.detectProviderFromModel(model).lowercased() == requestedProvider.lowercased()
                }

                if let firstModel = providerModels.first {
                    return firstModel
                } else {
                    TerminalOutput.print(
                        "⚠️  Provider '\(requestedProvider)' not available. Using default.",
                        color: .yellow)
                }
            }
        }

        // Auto-select the best available model
        // Prioritized by quality and general capabilities
        let preferredOrder = ["claude-opus-4-20250514", "gpt-4.1", "llama3.3", "grok-4"]

        for preferred in preferredOrder {
            if availableModels.contains(preferred) {
                return preferred
            }
        }

        // Fallback to first available
        return availableModels.first!
    }

    /// Display the response in a formatted way
    private func displayResponse(message: String, response: ModelResponse, model: String, duration: TimeInterval) {
        let provider = self.detectProviderFromModel(model)
        let emoji = TerminalOutput.providerEmoji(provider)

        TerminalOutput.separator("═")
        TerminalOutput.print("💬 Your message: \(message)", color: .cyan)
        TerminalOutput.separator("─")
        TerminalOutput.print("\(emoji) \(provider) response:", color: .bold)
        TerminalOutput.separator("─")

        // Extract text content from response
        // ModelResponse.content is an array of AssistantContent items
        let textContent = response.content.compactMap { item in
            if case let .outputText(text) = item {
                return text
            }
            return nil
        }.joined()

        if !textContent.isEmpty {
            TerminalOutput.print(textContent, color: .white)
        } else {
            TerminalOutput.print("(No text content in response)", color: .dim)
        }

        TerminalOutput.separator("─")

        // Show statistics
        let tokenCount = PerformanceMeasurement.estimateTokenCount(textContent)
        let stats = [
            "⏱️ Duration: \(String(format: "%.2fs", duration))",
            "🔤 Tokens: ~\(tokenCount)",
            "👻 Model: \(model)",
        ]

        TerminalOutput.print(stats.joined(separator: " | "), color: .dim)

        // Cost estimation if available
        if let cost = PerformanceMeasurement.estimateCost(
            provider: model,
            inputTokens: PerformanceMeasurement.estimateTokenCount(message),
            outputTokens: tokenCount)
        {
            TerminalOutput.print("💰 Estimated cost: $\(String(format: "%.4f", cost))", color: .green)
        } else {
            TerminalOutput.print("💰 Cost: Free (local model)", color: .green)
        }

        TerminalOutput.separator("═")

        if self.verbose {
            TerminalOutput.print("\n🎓 Key concepts demonstrated:", color: .yellow)
            TerminalOutput.print(
                "1. ✅ Environment-based configuration (AIConfiguration.fromEnvironment())",
                color: .dim)
            TerminalOutput.print("2. ✅ Provider-agnostic model access (modelProvider.getModel())", color: .dim)
            TerminalOutput.print("3. ✅ Unified request/response format across all providers", color: .dim)
            TerminalOutput.print("4. ✅ Error handling and graceful degradation", color: .dim)

            TerminalOutput.print("\n💡 Next steps:", color: .cyan)
            TerminalOutput.print("• Try: tachikoma-comparison \"Your question\" (side-by-side comparison)", color: .dim)
            TerminalOutput.print("• Try: tachikoma-streaming \"Tell me a story\" (real-time responses)", color: .dim)
            TerminalOutput.print("• Try: tachikoma-agent --help (AI agents with tool calling)", color: .dim)
        }
    }
}
