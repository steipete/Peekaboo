import Foundation
import ArgumentParser
import Tachikoma
import SharedExampleUtils

/// The killer demo: Compare AI providers side-by-side using Tachikoma
@main
struct TachikomaComparison: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tachikoma-comparison",
        abstract: "🚀 Compare AI provider responses side-by-side using Tachikoma",
        discussion: """
        This demo showcases Tachikoma's unique value proposition: seamlessly switching between
        AI providers with identical code. Send the same prompt to multiple providers and see
        their responses, performance, and costs compared side-by-side.
        
        Examples:
          tachikoma-comparison "Explain quantum computing"
          tachikoma-comparison --providers openai,anthropic "Write a Swift function"
          tachikoma-comparison --interactive
        """
    )
    
    @Argument(help: "The prompt to send to all providers")
    var prompt: String?
    
    @Option(name: .shortAndLong, help: "Comma-separated list of providers to compare (auto-detects if not specified)")
    var providers: String?
    
    @Flag(name: .shortAndLong, help: "Interactive mode - keep prompting for questions")
    var interactive: Bool = false
    
    @Flag(name: .shortAndLong, help: "Show verbose output including request/response details")
    var verbose: Bool = false
    
    @Option(help: "Maximum width for each provider column")
    var columnWidth: Int = 60
    
    @Option(help: "Maximum response length to display (0 = no limit)")
    var maxLength: Int = 500
    
    func run() async throws {
        // Setup and show available providers
        ConfigurationHelper.printSetupInstructions()
        
        // Create the model provider using environment-based configuration
        // This automatically detects all available API keys and sets up providers
        let modelProvider = try ConfigurationHelper.createProviderWithAvailableModels()
        let availableModels = modelProvider.availableModels()
        
        if availableModels.isEmpty {
            TerminalOutput.print("❌ No AI providers configured! Please set up API keys.", color: .red)
            TerminalOutput.print("See setup instructions above.", color: .yellow)
            return
        }
        
        // Determine which providers/models to use for comparison
        let modelsToCompare = try selectModelsToCompare(availableModels: availableModels)
        
        if modelsToCompare.isEmpty {
            TerminalOutput.print("❌ No valid providers selected.", color: .red)
            return
        }
        
        TerminalOutput.print("\n🎯 Comparing \(modelsToCompare.count) providers: \(modelsToCompare.joined(separator: ", "))", color: .green)
        
        if interactive {
            try await runInteractiveMode(modelProvider: modelProvider, models: modelsToCompare)
        } else {
            guard let prompt = prompt else {
                TerminalOutput.print("❌ Please provide a prompt or use --interactive mode", color: .red)
                return
            }
            try await compareProviders(prompt: prompt, modelProvider: modelProvider, models: modelsToCompare)
        }
    }
    
    /// Select which models to compare based on user preference and availability
    private func selectModelsToCompare(availableModels: [String]) throws -> [String] {
        if let providersString = providers {
            // User specified providers
            let requestedProviders = providersString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let providerToModel = ProviderDetector.recommendedModels()
            
            var selectedModels: [String] = []
            
            for provider in requestedProviders {
                // Make provider matching case-insensitive
                let normalizedProvider = provider.lowercased()
                let matchingKey = providerToModel.keys.first { key in
                    key.lowercased() == normalizedProvider
                }
                
                if let key = matchingKey, let recommendedModel = providerToModel[key] {
                    if availableModels.contains(recommendedModel) {
                        selectedModels.append(recommendedModel)
                    } else {
                        TerminalOutput.print("⚠️  Provider \(provider) not available (missing \(recommendedModel))", color: .yellow)
                    }
                } else {
                    TerminalOutput.print("⚠️  Unknown provider: \(provider)", color: .yellow)
                }
            }
            
            return selectedModels
        } else {
            // Auto-detect available providers, limit to 4 for display
            let recommended = ProviderDetector.recommendedModels()
            let availableProviders = recommended.values.filter { availableModels.contains($0) }
            
            // Prefer a good mix if we have many available
            let preferredOrder = ["gpt-4.1", "claude-opus-4-20250514", "llama3.3", "grok-4"]
            var selected: [String] = []
            
            for model in preferredOrder {
                if availableProviders.contains(model) && selected.count < 4 {
                    selected.append(model)
                }
            }
            
            // Fill remaining slots
            for model in availableProviders {
                if !selected.contains(model) && selected.count < 4 {
                    selected.append(model)
                }
            }
            
            return selected
        }
    }
    
    /// Run interactive mode where user can keep asking questions
    private func runInteractiveMode(modelProvider: AIModelProvider, models: [String]) async throws {
        TerminalOutput.header("🎭 Interactive AI Provider Comparison")
        TerminalOutput.print("Type your questions and see how different AI providers respond!", color: .cyan)
        TerminalOutput.print("Type 'quit' or 'exit' to stop.", color: .dim)
        TerminalOutput.separator()
        
        while true {
            TerminalOutput.print("\n💭 Your question: ", color: .magenta)
            
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
            
            try await compareProviders(prompt: input, modelProvider: modelProvider, models: models)
        }
    }
    
    /// The main comparison logic - this is where Tachikoma really shines!
    private func compareProviders(prompt: String, modelProvider: AIModelProvider, models: [String]) async throws {
        TerminalOutput.print("\n" + String(repeating: "═", count: 100), color: .blue)
        TerminalOutput.print("🤔 Prompt: \(prompt)", color: .bold)
        TerminalOutput.print(String(repeating: "═", count: 100), color: .blue)
        
        // Send requests to all providers concurrently
        // This demonstrates Tachikoma's power: same code, multiple providers
        var comparisons: [ResponseComparison] = []
        
        try await withThrowingTaskGroup(of: ResponseComparison.self) { group in
            // Start all provider requests in parallel
            for model in models {
                group.addTask {
                    try await self.getResponseFromProvider(
                        prompt: prompt,
                        modelProvider: modelProvider,
                        modelName: model
                    )
                }
            }
            
            // Collect results as they complete
            for try await comparison in group {
                comparisons.append(comparison)
            }
        }
        
        // Sort by provider name for consistent display
        comparisons.sort { $0.provider < $1.provider }
        
        // Display results in requested format
        if verbose {
            displayVerboseResults(comparisons)
        } else {
            displayCompactResults(comparisons)
        }
        
        // Display summary statistics
        displaySummaryStats(comparisons)
    }
    
    /// Get response from a single provider with performance measurement
    private func getResponseFromProvider(prompt: String, modelProvider: AIModelProvider, modelName: String) async throws -> ResponseComparison {
        do {
            // Get the model instance - same interface for all providers
            let model = try modelProvider.getModel(modelName)
            let providerName = getProviderName(from: modelName)
            
            // Measure performance while getting the response
            let (response, duration) = try await PerformanceMeasurement.measure {
                // Create a standard request that works with any provider
                let request = ModelRequest(
                    messages: [Message.user(content: .text(prompt))],
                    tools: nil, // No function calling for comparison
                    settings: ModelSettings(maxTokens: 500) // Limit response length
                )
                
                let result = try await model.getResponse(request: request)
                
                // Extract text content from response
                // All providers return the same AssistantContent format
                let textContent = result.content.compactMap { item in
                    if case let .outputText(text) = item {
                        return text
                    }
                    return nil
                }.joined()
                
                return textContent.isEmpty ? "No response" : textContent
            }
            
            let tokenCount = PerformanceMeasurement.estimateTokenCount(response)
            let cost = PerformanceMeasurement.estimateCost(
                provider: modelName,
                inputTokens: PerformanceMeasurement.estimateTokenCount(prompt),
                outputTokens: tokenCount
            )
            
            return ResponseComparison(
                provider: providerName,
                response: response,
                duration: duration,
                tokenCount: tokenCount,
                estimatedCost: cost
            )
            
        } catch {
            let providerName = getProviderName(from: modelName)
            return ResponseComparison(
                provider: providerName,
                response: "",
                duration: 0,
                tokenCount: 0,
                estimatedCost: nil,
                error: error.localizedDescription
            )
        }
    }
    
    /// Extract provider name from model name
    private func getProviderName(from modelName: String) -> String {
        switch modelName.lowercased() {
        case let m where m.contains("gpt") || m.contains("o3") || m.contains("o4"):
            return "OpenAI \(modelName)"
        case let m where m.contains("claude"):
            return "Anthropic \(modelName)"
        case let m where m.contains("llama") || m.contains("llava"):
            return "Ollama \(modelName)"
        case let m where m.contains("grok"):
            return "Grok \(modelName)"
        default:
            return modelName
        }
    }
    
    /// Display results in compact side-by-side format
    private func displayCompactResults(_ comparisons: [ResponseComparison]) {
        let formatted = ResponseFormatter.formatSideBySide(comparisons, maxWidth: columnWidth)
        print(formatted)
    }
    
    /// Display verbose results with full details
    private func displayVerboseResults(_ comparisons: [ResponseComparison]) {
        for comparison in comparisons {
            TerminalOutput.separator("─", length: 100)
            TerminalOutput.providerHeader(comparison.provider)
            
            if let error = comparison.error {
                TerminalOutput.print("❌ Error: \(error)", color: .red)
            } else {
                TerminalOutput.print(comparison.response, color: .white)
                
                let stats = ResponseFormatter.formatStats(comparison)
                TerminalOutput.print("\n\(stats)", color: .dim)
            }
            
            TerminalOutput.separator("─", length: 100)
        }
    }
    
    /// Display summary statistics
    private func displaySummaryStats(_ comparisons: [ResponseComparison]) {
        let successful = comparisons.filter { $0.error == nil }
        
        if successful.isEmpty {
            TerminalOutput.print("\n❌ All providers failed", color: .red)
            return
        }
        
        TerminalOutput.print("\n📊 Summary Statistics:", color: .bold)
        
        // Speed comparison
        let fastest = successful.min(by: { $0.duration < $1.duration })!
        let slowest = successful.max(by: { $0.duration < $1.duration })!
        
        TerminalOutput.print("⚡ Fastest: \(fastest.provider) (\(String(format: "%.2fs", fastest.duration)))", color: .green)
        TerminalOutput.print("🐌 Slowest: \(slowest.provider) (\(String(format: "%.2fs", slowest.duration)))", color: .yellow)
        
        // Cost comparison (if available)
        let withCosts = successful.filter { $0.estimatedCost != nil }
        if !withCosts.isEmpty {
            let cheapest = withCosts.min(by: { $0.estimatedCost! < $1.estimatedCost! })!
            let mostExpensive = withCosts.max(by: { $0.estimatedCost! < $1.estimatedCost! })!
            
            TerminalOutput.print("💰 Cheapest: \(cheapest.provider) ($\(String(format: "%.4f", cheapest.estimatedCost!)))", color: .green)
            TerminalOutput.print("💸 Most Expensive: \(mostExpensive.provider) ($\(String(format: "%.4f", mostExpensive.estimatedCost!)))", color: .yellow)
        }
        
        // Response length comparison
        let longest = successful.max(by: { $0.response.count < $1.response.count })!
        let shortest = successful.min(by: { $0.response.count < $1.response.count })!
        
        TerminalOutput.print("📏 Longest response: \(longest.provider) (\(longest.response.count) chars)", color: .cyan)
        TerminalOutput.print("📏 Shortest response: \(shortest.provider) (\(shortest.response.count) chars)", color: .cyan)
        
        TerminalOutput.separator()
    }
}