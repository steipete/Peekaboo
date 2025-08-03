import Foundation
import ArgumentParser
import Tachikoma
import SharedExampleUtils

/// Demonstrate real-time streaming responses from AI providers
@main
struct TachikomaStreaming: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tachikoma-streaming",
        abstract: "⚡ Experience real-time streaming responses from AI providers",
        discussion: """
        This example demonstrates Tachikoma's streaming capabilities, showing how different
        providers deliver responses in real-time. Perfect for understanding performance
        characteristics and user experience differences between providers.
        
        Examples:
          tachikoma-streaming "Tell me a story about robots"
          tachikoma-streaming --race "Compare streaming speeds across providers"
          tachikoma-streaming --provider anthropic "Write a detailed explanation"
        """
    )
    
    @Argument(help: "The prompt to stream responses for")
    var prompt: String?
    
    @Option(name: .shortAndLong, help: "Specific provider to use for streaming")
    var provider: String?
    
    @Flag(name: .long, help: "Race mode - stream from multiple providers simultaneously")
    var race: Bool = false
    
    @Flag(name: .shortAndLong, help: "Show verbose streaming information")
    var verbose: Bool = false
    
    @Option(help: "Maximum tokens to stream (default: 1000)")
    var maxTokens: Int = 1000
    
    @Option(help: "Character delay between streamed words (milliseconds)")
    var delayMs: Int = 50
    
    func run() async throws {
        TerminalOutput.header("⚡ Tachikoma Streaming Demo")
        
        guard let prompt = prompt else {
            TerminalOutput.print("❌ Please provide a prompt to stream", color: .red)
            return
        }
        
        let modelProvider = try ConfigurationHelper.createProviderWithAvailableModels()
        let availableModels = modelProvider.availableModels()
        
        if availableModels.isEmpty {
            TerminalOutput.print("❌ No AI providers configured! Please set up API keys.", color: .red)
            ConfigurationHelper.printSetupInstructions()
            return
        }
        
        if race {
            try await runRaceMode(prompt: prompt, modelProvider: modelProvider, availableModels: availableModels)
        } else {
            try await runSingleStream(prompt: prompt, modelProvider: modelProvider, availableModels: availableModels)
        }
    }
    
    /// Stream from a single provider to demonstrate real-time responses
    private func runSingleStream(prompt: String, modelProvider: AIModelProvider, availableModels: [String]) async throws {
        let selectedModel = try selectModel(from: availableModels)
        let model = try modelProvider.getModel(selectedModel)
        let providerName = getProviderName(from: selectedModel)
        
        TerminalOutput.print("🎯 Streaming from: \(providerName)", color: .cyan)
        TerminalOutput.print("💭 Prompt: \(prompt)", color: .dim)
        TerminalOutput.separator("─")
        
        // Track performance metrics
        let startTime = Date()
        var totalTokens = 0
        var firstTokenTime: Date?
        
        // Create the streaming request
        let request = ModelRequest(
            messages: [Message.user(content: .text(prompt))],
            tools: nil, // No function calling for streaming demo
            settings: ModelSettings(maxTokens: maxTokens)
        )
        
        if verbose {
            TerminalOutput.print("📡 Starting stream request...", color: .yellow)
        }
        
        do {
            let emoji = TerminalOutput.providerEmoji(providerName)
            TerminalOutput.print("\(emoji) \(providerName) response:", color: .bold)
            TerminalOutput.separator("─")
            
            var responseText = ""
            
            // Process the streaming response
            // getStreamedResponse() returns an AsyncSequence of StreamEvent
            for try await event in try await model.getStreamedResponse(request: request) {
                if firstTokenTime == nil {
                    firstTokenTime = Date()
                    if verbose {
                        let timeToFirst = Date().timeIntervalSince(startTime)
                        TerminalOutput.print("\n⚡ First token received in \(String(format: "%.2fs", timeToFirst))", color: .green)
                    }
                }
                
                // Handle different types of streaming events
                switch event {
                case .textDelta(let delta):
                    // Text content arrives incrementally as the model generates it
                    let text = delta.delta
                    responseText += text
                    print(text, terminator: "") // Print immediately for real-time effect
                    fflush(stdout)
                    totalTokens += PerformanceMeasurement.estimateTokenCount(text)
                    
                    // Optional: Add artificial delay to visualize streaming
                    if delayMs > 0 {
                        try await Task.sleep(nanoseconds: UInt64(delayMs * 1_000_000))
                    }
                case .responseCompleted:
                    // Stream has finished - break out of the loop
                    break
                case .error(let errorEvent):
                    // Handle streaming errors
                    throw NSError(domain: "StreamingError", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: errorEvent.error.message
                    ])
                default:
                    // Handle other event types silently (metadata, etc.)
                    break
                }
            }
            
            let endTime = Date()
            let totalDuration = endTime.timeIntervalSince(startTime)
            let timeToFirst = firstTokenTime?.timeIntervalSince(startTime) ?? 0
            
            print("\n")
            TerminalOutput.separator("─")
            
            // Display streaming statistics
            displayStreamingStats(
                provider: providerName,
                model: selectedModel,
                totalDuration: totalDuration,
                timeToFirst: timeToFirst,
                totalTokens: totalTokens,
                responseLength: responseText.count
            )
            
        } catch {
            TerminalOutput.print("\n❌ Streaming failed: \(error)", color: .red)
        }
    }
    
    /// Race mode - stream from multiple providers simultaneously
    private func runRaceMode(prompt: String, modelProvider: AIModelProvider, availableModels: [String]) async throws {
        let racingModels = selectRacingModels(from: availableModels)
        
        if racingModels.count < 2 {
            TerminalOutput.print("❌ Need at least 2 providers for race mode. Configure more API keys.", color: .red)
            return
        }
        
        TerminalOutput.print("🏁 Racing \(racingModels.count) providers:", color: .cyan)
        for model in racingModels {
            let provider = getProviderName(from: model)
            let emoji = TerminalOutput.providerEmoji(provider)
            TerminalOutput.print("  \(emoji) \(provider)", color: .white)
        }
        
        TerminalOutput.print("\n💭 Prompt: \(prompt)", color: .dim)
        TerminalOutput.separator("═")
        
        // Create racing lanes
        var completionOrder: [String] = []
        var raceResults: [RaceResult] = []
        
        try await withThrowingTaskGroup(of: RaceResult.self) { group in
            for model in racingModels {
                group.addTask {
                    try await self.runRacingStream(
                        prompt: prompt,
                        modelProvider: modelProvider,
                        modelName: model
                    )
                }
            }
            
            var position = 1
            for try await result in group {
                result.finishPosition = position
                raceResults.append(result)
                completionOrder.append(result.provider)
                position += 1
                
                let emoji = TerminalOutput.providerEmoji(result.provider)
                TerminalOutput.print("🏁 #\(result.finishPosition): \(emoji) \(result.provider) finished! (\(String(format: "%.2fs", result.totalDuration)))", color: result.finishPosition == 1 ? .green : .yellow)
            }
        }
        
        // Display race results
        displayRaceResults(raceResults.sorted { $0.finishPosition < $1.finishPosition })
    }
    
    /// Run a single racing stream
    private func runRacingStream(prompt: String, modelProvider: AIModelProvider, modelName: String) async throws -> RaceResult {
        let model = try modelProvider.getModel(modelName)
        let providerName = getProviderName(from: modelName)
        
        let startTime = Date()
        var firstTokenTime: Date?
        var totalTokens = 0
        var responseText = ""
        
        let request = ModelRequest(
            messages: [Message.user(content: .text(prompt))],
            tools: nil,
            settings: ModelSettings(maxTokens: maxTokens / 2)  // Shorter for racing
        )
        
        do {
            for try await event in try await model.getStreamedResponse(request: request) {
                if firstTokenTime == nil {
                    firstTokenTime = Date()
                }
                
                // Handle different event types
                switch event {
                case .textDelta(let delta):
                    let text = delta.delta
                    responseText += text
                    totalTokens += PerformanceMeasurement.estimateTokenCount(text)
                case .responseCompleted:
                    break
                case .error(let errorEvent):
                    throw NSError(domain: "StreamingError", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: errorEvent.error.message
                    ])
                default:
                    // Handle other event types silently
                    break
                }
            }
            
            let endTime = Date()
            let totalDuration = endTime.timeIntervalSince(startTime)
            let timeToFirst = firstTokenTime?.timeIntervalSince(startTime) ?? 0
            
            return RaceResult(
                provider: providerName,
                model: modelName,
                totalDuration: totalDuration,
                timeToFirst: timeToFirst,
                totalTokens: totalTokens,
                responseLength: responseText.count,
                responsePreview: String(responseText.prefix(100)),
                finishPosition: 0  // Will be set later
            )
            
        } catch {
            // Return error result
            return RaceResult(
                provider: providerName,
                model: modelName,
                totalDuration: 0,
                timeToFirst: 0,
                totalTokens: 0,
                responseLength: 0,
                responsePreview: "Error: \(error.localizedDescription)",
                finishPosition: 999,
                error: error.localizedDescription
            )
        }
    }
    
    /// Select a single model based on user preference
    private func selectModel(from availableModels: [String]) throws -> String {
        if let requestedProvider = provider {
            let recommended = ProviderDetector.recommendedModels()
            
            if let recommendedModel = recommended[requestedProvider.capitalized],
               availableModels.contains(recommendedModel) {
                return recommendedModel
            } else {
                // Find any model from the requested provider
                let providerModels = availableModels.filter { model in
                    getProviderName(from: model).lowercased().contains(requestedProvider.lowercased())
                }
                
                if let firstModel = providerModels.first {
                    return firstModel
                } else {
                    throw NSError(domain: "TachikomaStreaming", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "Provider '\(requestedProvider)' not available"
                    ])
                }
            }
        }
        
        // Auto-select best available for streaming
        let streamingPreferred = ["claude-opus-4-20250514", "gpt-4.1", "llama3.3", "grok-4"]
        
        for preferred in streamingPreferred {
            if availableModels.contains(preferred) {
                return preferred
            }
        }
        
        return availableModels.first!
    }
    
    /// Select models for racing (up to 4)
    private func selectRacingModels(from availableModels: [String]) -> [String] {
        let recommended = ProviderDetector.recommendedModels()
        let availableProviderModels = recommended.values.filter { availableModels.contains($0) }
        
        // Prefer a good mix for racing
        let racingOrder = ["gpt-4.1", "claude-opus-4-20250514", "llama3.3", "grok-4"]
        var selected: [String] = []
        
        for model in racingOrder {
            if availableProviderModels.contains(model) && selected.count < 4 {
                selected.append(model)
            }
        }
        
        return selected
    }
    
    /// Extract provider name from model name
    private func getProviderName(from modelName: String) -> String {
        switch modelName.lowercased() {
        case let m where m.contains("gpt") || m.contains("o3") || m.contains("o4"):
            return "OpenAI"
        case let m where m.contains("claude"):
            return "Anthropic"
        case let m where m.contains("llama") || m.contains("llava"):
            return "Ollama"
        case let m where m.contains("grok"):
            return "Grok"
        default:
            return "Unknown"
        }
    }
    
    /// Display streaming statistics
    private func displayStreamingStats(provider: String, model: String, totalDuration: TimeInterval, timeToFirst: TimeInterval, totalTokens: Int, responseLength: Int) {
        TerminalOutput.print("📊 Streaming Statistics:", color: .bold)
        
        let tokensPerSecond = totalTokens > 0 ? Double(totalTokens) / totalDuration : 0
        let charsPerSecond = responseLength > 0 ? Double(responseLength) / totalDuration : 0
        
        let stats = [
            "⏱️ Total time: \(String(format: "%.2fs", totalDuration))",
            "🚀 Time to first token: \(String(format: "%.2fs", timeToFirst))",
            "📊 Streaming rate: \(String(format: "%.1f", tokensPerSecond)) tokens/sec",
            "⚡ Character rate: \(String(format: "%.0f", charsPerSecond)) chars/sec",
            "🔤 Total tokens: \(totalTokens)",
            "📏 Response length: \(responseLength) characters"
        ]
        
        for stat in stats {
            TerminalOutput.print("  \(stat)", color: .dim)
        }
        
        // Performance rating
        let rating = getPerformanceRating(timeToFirst: timeToFirst, tokensPerSecond: tokensPerSecond)
        TerminalOutput.print("\n🎯 Performance: \(rating)", color: .cyan)
        
        if let cost = PerformanceMeasurement.estimateCost(
            provider: model,
            inputTokens: PerformanceMeasurement.estimateTokenCount(prompt ?? ""),
            outputTokens: totalTokens
        ) {
            TerminalOutput.print("💰 Estimated cost: $\(String(format: "%.4f", cost))", color: .green)
        } else {
            TerminalOutput.print("💰 Cost: Free (local model)", color: .green)
        }
    }
    
    /// Display race results
    private func displayRaceResults(_ results: [RaceResult]) {
        TerminalOutput.separator("═")
        TerminalOutput.print("🏆 Final Race Results:", color: .bold)
        TerminalOutput.separator("─")
        
        for result in results {
            let emoji = TerminalOutput.providerEmoji(result.provider)
            let medal = getMedal(result.finishPosition)
            
            if let error = result.error {
                TerminalOutput.print("\(medal) \(emoji) \(result.provider): ❌ \(error)", color: .red)
            } else {
                let tokensPerSecond = result.totalTokens > 0 ? Double(result.totalTokens) / result.totalDuration : 0
                TerminalOutput.print("\(medal) \(emoji) \(result.provider):", color: result.finishPosition == 1 ? .green : .white)
                TerminalOutput.print("    ⏱️ \(String(format: "%.2fs", result.totalDuration)) | 🚀 \(String(format: "%.2fs", result.timeToFirst)) TTFT | ⚡ \(String(format: "%.1f", tokensPerSecond)) tok/sec", color: .dim)
                if !result.responsePreview.isEmpty {
                    TerminalOutput.print("    💬 \"\(result.responsePreview)...\"", color: .dim)
                }
            }
        }
        
        TerminalOutput.separator("─")
        
        // Race analysis
        let successful = results.filter { $0.error == nil }
        if successful.count >= 2 {
            let fastest = successful.min(by: { $0.totalDuration < $1.totalDuration })!
            let slowest = successful.max(by: { $0.totalDuration < $1.totalDuration })!
            
            TerminalOutput.print("🔍 Race Analysis:", color: .yellow)
            TerminalOutput.print("  🥇 Winner: \(fastest.provider) (\(String(format: "%.2fs", fastest.totalDuration)))", color: .green)
            TerminalOutput.print("  🐌 Slowest: \(slowest.provider) (\(String(format: "%.2fs", slowest.totalDuration)))", color: .yellow)
            
            let speedDifference = slowest.totalDuration - fastest.totalDuration
            let percentFaster = (speedDifference / slowest.totalDuration) * 100
            TerminalOutput.print("  ⚡ Speed advantage: \(String(format: "%.1f%%", percentFaster)) faster", color: .cyan)
        }
    }
    
    /// Get performance rating based on metrics
    private func getPerformanceRating(timeToFirst: TimeInterval, tokensPerSecond: Double) -> String {
        if timeToFirst < 1.0 && tokensPerSecond > 50 {
            return "🚀 Excellent (Very fast response and streaming)"
        } else if timeToFirst < 2.0 && tokensPerSecond > 30 {
            return "⚡ Good (Fast streaming)"
        } else if timeToFirst < 5.0 && tokensPerSecond > 15 {
            return "👍 Fair (Acceptable speed)"
        } else {
            return "🐌 Slow (Consider different provider)"
        }
    }
    
    /// Get medal emoji for race position
    private func getMedal(_ position: Int) -> String {
        switch position {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "🔸"
        }
    }
}

// MARK: - Supporting Types

/// Result of a racing stream
class RaceResult: @unchecked Sendable {
    let provider: String
    let model: String
    let totalDuration: TimeInterval
    let timeToFirst: TimeInterval
    let totalTokens: Int
    let responseLength: Int
    let responsePreview: String
    var finishPosition: Int
    let error: String?
    
    init(provider: String, model: String, totalDuration: TimeInterval, timeToFirst: TimeInterval, totalTokens: Int, responseLength: Int, responsePreview: String, finishPosition: Int, error: String? = nil) {
        self.provider = provider
        self.model = model
        self.totalDuration = totalDuration
        self.timeToFirst = timeToFirst
        self.totalTokens = totalTokens
        self.responseLength = responseLength
        self.responsePreview = responsePreview
        self.finishPosition = finishPosition
        self.error = error
    }
}