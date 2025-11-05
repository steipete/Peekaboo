import Foundation
import Tachikoma

// MARK: - Terminal Output Utilities

/// Utility functions for colorized terminal output and formatting
/// Used across all Tachikoma examples for consistent, beautiful CLI output
public enum TerminalOutput {
    /// ANSI color codes for terminal output
    public enum Color: String {
        case red = "\u{001B}[31m"
        case green = "\u{001B}[32m"
        case yellow = "\u{001B}[33m"
        case blue = "\u{001B}[34m"
        case magenta = "\u{001B}[35m"
        case cyan = "\u{001B}[36m"
        case white = "\u{001B}[37m"
        case reset = "\u{001B}[0m"
        case bold = "\u{001B}[1m"
        case dim = "\u{001B}[2m"
    }

    /// Print colored text to terminal
    public static func print(_ text: String, color: Color = .reset) {
        Swift.print("\(color.rawValue)\(text)\(Color.reset.rawValue)")
    }

    /// Print a separator line
    public static func separator(_ char: Character = "─", length: Int = 80) {
        Swift.print(String(repeating: char, count: length))
    }

    /// Print a section header
    public static func header(_ title: String) {
        self.separator("═")
        self.print(" \(title) ", color: .bold)
        self.separator("═")
    }

    /// Print provider name with emoji
    public static func providerHeader(_ provider: String) {
        let emoji = self.providerEmoji(provider)
        self.print("\(emoji) \(provider)", color: .cyan)
    }

    /// Get emoji for provider - makes provider identification visual and fun
    public static func providerEmoji(_ provider: String) -> String {
        switch provider.lowercased() {
        case let p where p.contains("openai") || p.contains("gpt"):
            "👻" // OpenAI - robot/AI theme
        case let p where p.contains("anthropic") || p.contains("claude"):
            "🧠" // Anthropic - brain/thinking theme
        case let p where p.contains("ollama") || p.contains("llama"):
            "🦙" // Ollama - llama theme
        case let p where p.contains("grok"):
            "🚀" // Grok - rocket/fast theme
        default:
            "👻"
        }
    }
}

// MARK: - Response Comparison Utilities

/// Utility for comparing responses from different providers
public struct ResponseComparison: Sendable {
    public let provider: String
    public let response: String
    public let duration: TimeInterval
    public let tokenCount: Int
    public let estimatedCost: Double?
    public let error: String?

    public init(
        provider: String,
        response: String,
        duration: TimeInterval,
        tokenCount: Int,
        estimatedCost: Double? = nil,
        error: String? = nil)
    {
        self.provider = provider
        self.response = response
        self.duration = duration
        self.tokenCount = tokenCount
        self.estimatedCost = estimatedCost
        self.error = error
    }
}

/// Format response comparison in a nice table
public enum ResponseFormatter {
    /// Format responses side by side
    public static func formatSideBySide(_ comparisons: [ResponseComparison], maxWidth: Int = 60) -> String {
        var output = ""

        // Create header
        let headers = comparisons.map { comparison in
            let emoji = TerminalOutput.providerEmoji(comparison.provider)
            return "\(emoji) \(comparison.provider)"
        }

        // Print headers with boxes
        let headerLine = headers.map { _ in
            "┌\(String(repeating: "─", count: maxWidth))┐"
        }.joined(separator: " ")

        output += headerLine + "\n"

        let headerContentLine = headers.map { header in
            let padding = max(0, maxWidth - header.count)
            let leftPad = padding / 2
            let rightPad = padding - leftPad
            return "│\(String(repeating: " ", count: leftPad))\(header)\(String(repeating: " ", count: rightPad))│"
        }.joined(separator: " ")

        output += headerContentLine + "\n"

        // Content area
        let maxLines = comparisons.map { $0.response.split(separator: "\n").count }.max() ?? 0

        for lineIndex in 0..<maxLines {
            let contentLine = comparisons.map { comparison in
                let lines = comparison.response.split(separator: "\n")
                let line = lineIndex < lines.count ? String(lines[lineIndex]) : ""
                let truncated = line.count > maxWidth - 4 ? String(line.prefix(maxWidth - 7)) + "..." : line
                let padding = maxWidth - truncated.count
                return "│ \(truncated)\(String(repeating: " ", count: padding - 1))│"
            }.joined(separator: " ")

            output += contentLine + "\n"
        }

        // Footer with stats
        let footerLine = comparisons.map { comparison in
            let stats = self.formatStats(comparison)
            let padding = max(0, maxWidth - stats.count)
            return "│ \(stats)\(String(repeating: " ", count: padding - 1))│"
        }.joined(separator: " ")

        output += footerLine + "\n"

        let bottomLine = comparisons.map { _ in
            "└\(String(repeating: "─", count: maxWidth))┘"
        }.joined(separator: " ")

        output += bottomLine + "\n"

        return output
    }

    /// Format statistics line for a comparison
    public static func formatStats(_ comparison: ResponseComparison) -> String {
        let timeStr = String(format: "⏱️ %.1fs", comparison.duration)
        let tokenStr = "🔤 \(comparison.tokenCount) tokens"

        var stats = "\(timeStr) | \(tokenStr)"

        if let cost = comparison.estimatedCost {
            let costStr = String(format: "💰 $%.4f", cost)
            stats += " | \(costStr)"
        } else {
            stats += " | 💰 Free"
        }

        return stats
    }
}

// MARK: - Provider Detection and Setup

/// Utility for detecting available providers based on environment variables
public enum ProviderDetector {
    /// Detect which providers are available based on environment variables
    /// This helps examples gracefully handle missing API keys
    public static func detectAvailableProviders() -> [String] {
        var providers: [String] = []

        // Check for API keys in environment variables
        if ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil {
            providers.append("OpenAI")
        }

        if ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil {
            providers.append("Anthropic")
        }

        if ProcessInfo.processInfo.environment["X_AI_API_KEY"] != nil ||
            ProcessInfo.processInfo.environment["XAI_API_KEY"] != nil
        {
            providers.append("Grok")
        }

        // Ollama is always available (assuming local installation)
        providers.append("Ollama")

        return providers
    }

    /// Get recommended model for each provider - updated with latest models
    public static func recommendedModels() -> [String: String] {
        [
            "OpenAI": "gpt-4.1", // Latest GPT-4.1
            "Anthropic": "claude-opus-4-20250514", // Claude Opus 4 (May 2025)
            "Grok": "grok-4", // Latest Grok
            "Ollama": "llama3.3", // Best Ollama model for function calling
        ]
    }
}

// MARK: - Configuration Helpers

/// Helper for creating provider configurations
public enum ConfigurationHelper {
    /// Create AIModelProvider with recommended models for available providers
    public static func createProviderWithAvailableModels() throws -> AIModelProvider {
        try AIConfiguration.fromEnvironment()
    }

    /// Get available model names
    public static func getAvailableModelNames() throws -> [String] {
        let provider = try createProviderWithAvailableModels()
        return provider.availableModels()
    }

    /// Print setup instructions for missing providers
    public static func printSetupInstructions() {
        TerminalOutput.header("🚀 Tachikoma Examples Setup")

        let available = ProviderDetector.detectAvailableProviders()

        TerminalOutput.print("Available providers: \(available.joined(separator: ", "))", color: .green)

        if !available.contains("OpenAI") {
            TerminalOutput.print("\n💡 To enable OpenAI:", color: .yellow)
            TerminalOutput.print("   export OPENAI_API_KEY=sk-your-key-here", color: .dim)
        }

        if !available.contains("Anthropic") {
            TerminalOutput.print("\n💡 To enable Anthropic:", color: .yellow)
            TerminalOutput.print("   export ANTHROPIC_API_KEY=sk-ant-your-key-here", color: .dim)
        }

        if !available.contains("Grok") {
            TerminalOutput.print("\n💡 To enable Grok:", color: .yellow)
            TerminalOutput.print("   export X_AI_API_KEY=xai-your-key-here", color: .dim)
        }

        if available.contains("Ollama") {
            TerminalOutput.print("\n🦙 For Ollama, ensure these models are installed:", color: .cyan)
            TerminalOutput.print("   ollama pull llama3.3", color: .dim)
            TerminalOutput.print("   ollama pull llava", color: .dim)
        }

        TerminalOutput.separator()
    }
}

// MARK: - Performance Measurement

/// Utility for measuring performance
public enum PerformanceMeasurement {
    /// Measure execution time of an async operation
    public static func measure<T>(_ operation: () async throws -> T) async rethrows
    -> (result: T, duration: TimeInterval) {
        let startTime = Date()
        let result = try await operation()
        let endTime = Date()
        return (result, endTime.timeIntervalSince(startTime))
    }

    /// Estimate token count (rough approximation)
    public static func estimateTokenCount(_ text: String) -> Int {
        // Rough approximation: ~4 characters per token
        text.count / 4
    }

    /// Estimate cost based on provider and token count
    public static func estimateCost(provider: String, inputTokens: Int, outputTokens: Int) -> Double? {
        switch provider.lowercased() {
        case let p where p.contains("gpt-4.1"):
            Double(inputTokens) * 0.00003 + Double(outputTokens) * 0.00012 // $30/$120 per 1M tokens
        case let p where p.contains("gpt-4o"):
            Double(inputTokens) * 0.000005 + Double(outputTokens) * 0.000015 // $5/$15 per 1M tokens
        case let p where p.contains("claude-opus-4"):
            Double(inputTokens) * 0.000015 + Double(outputTokens) * 0.000075 // $15/$75 per 1M tokens
        case let p where p.contains("claude-sonnet-4"):
            Double(inputTokens) * 0.000003 + Double(outputTokens) * 0.000015 // $3/$15 per 1M tokens
        case let p where p.contains("grok"):
            Double(inputTokens) * 0.000005 + Double(outputTokens) * 0.000015 // Estimated pricing
        case let p where p.contains("ollama") || p.contains("llama"):
            nil // Free (local)
        default:
            nil
        }
    }
}

// MARK: - Example Content

/// Predefined content for examples
public enum ExampleContent {
    /// Sample prompts for different use cases
    public static let samplePrompts = [
        "Explain quantum computing in simple terms",
        "Write a Swift function to calculate fibonacci numbers",
        "What are the key differences between async/await and callbacks?",
        "Describe the architecture of a modern web application",
        "How do neural networks learn?",
    ]

    /// Sample images for multimodal examples (base64 encoded)
    public static let sampleImages: [String: String] = [
        "chart": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==",
        // Add more sample images as needed
    ]

    /// Sample tools for agent examples
    public static let sampleTools = [
        "weather": "Get current weather for a location",
        "calculator": "Perform mathematical calculations",
        "file_reader": "Read contents of text files",
        "web_search": "Search the web for information",
    ]
}
