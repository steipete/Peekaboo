import Foundation
import ArgumentParser
import Tachikoma
import SharedExampleUtils

/// Demonstrate multimodal AI capabilities (vision + text) using Tachikoma
@main
struct TachikomaMultimodal: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tachikoma-multimodal",
        abstract: "👁️ Explore multimodal AI with vision and text processing",
        discussion: """
        This example showcases Tachikoma's multimodal capabilities, demonstrating how different
        AI providers handle image analysis, OCR, visual reasoning, and combining visual and
        textual information. Compare vision capabilities across providers.
        
        Examples:
          tachikoma-multimodal --image chart.png "Analyze this chart"
          tachikoma-multimodal --image photo.jpg --compare-vision "What do you see?"
          tachikoma-multimodal --ocr document.png "Extract all text"
          tachikoma-multimodal --describe screenshot.png
        """
    )
    
    @Option(name: .shortAndLong, help: "Path to image file to analyze")
    var image: String?
    
    @Argument(help: "Text prompt about the image")
    var prompt: String?
    
    @Option(name: .shortAndLong, help: "Specific provider to use")
    var provider: String?
    
    @Flag(name: .long, help: "Compare vision capabilities across multiple providers")
    var compareVision: Bool = false
    
    @Flag(name: .long, help: "Perform OCR (Optical Character Recognition) on the image")
    var ocr: Bool = false
    
    @Flag(name: .long, help: "Just describe what's in the image without additional prompt")
    var describe: Bool = false
    
    @Flag(name: .shortAndLong, help: "Show verbose analysis details")
    var verbose: Bool = false
    
    @Flag(name: .long, help: "List vision-capable models and exit")
    var listVisionModels: Bool = false
    
    @Option(help: "Max dimension for image processing (default: 1024)")
    var maxDimension: Int = 1024
    
    func run() async throws {
        TerminalOutput.header("👁️ Tachikoma Multimodal Demo")
        
        let modelProvider = try ConfigurationHelper.createProviderWithAvailableModels()
        let availableModels = modelProvider.availableModels()
        
        if availableModels.isEmpty {
            TerminalOutput.print("❌ No AI providers configured! Please set up API keys.", color: .red)
            ConfigurationHelper.printSetupInstructions()
            return
        }
        
        if listVisionModels {
            listAvailableVisionModels(availableModels)
            return
        }
        
        guard let imagePath = image else {
            TerminalOutput.print("❌ Please provide an image file with --image", color: .red)
            return
        }
        
        // Load and validate the image file
        let imageData = try loadImage(from: imagePath)
        
        // Determine the final prompt based on flags and user input
        let finalPrompt = determineFinalPrompt()
        
        if compareVision {
            // Compare how different providers analyze the same image
            try await compareVisionAcrossProviders(
                imageData: imageData,
                imagePath: imagePath,
                prompt: finalPrompt,
                modelProvider: modelProvider,
                availableModels: availableModels
            )
        } else {
            // Analyze with a single provider
            try await analyzeSingleProvider(
                imageData: imageData,
                imagePath: imagePath,
                prompt: finalPrompt,
                modelProvider: modelProvider,
                availableModels: availableModels
            )
        }
    }
    
    /// List available vision models
    private func listAvailableVisionModels(_ availableModels: [String]) {
        TerminalOutput.print("👁️ Vision-Capable Models:", color: .cyan)
        TerminalOutput.separator("─")
        
        let visionModels = getVisionCapableModels(availableModels)
        
        if visionModels.isEmpty {
            TerminalOutput.print("❌ No vision-capable models available", color: .red)
            TerminalOutput.print("💡 Vision models require: GPT-4V, Claude 3+, or LLaVA", color: .yellow)
            return
        }
        
        for model in visionModels {
            let provider = getProviderName(from: model)
            let emoji = TerminalOutput.providerEmoji(provider)
            let capabilities = getModelCapabilities(model)
            
            TerminalOutput.print("\(emoji) \(model)", color: .white)
            TerminalOutput.print("   Capabilities: \(capabilities.joined(separator: ", "))", color: .dim)
        }
        
        TerminalOutput.separator("─")
        TerminalOutput.print("💡 Use --compare-vision to test multiple models at once", color: .yellow)
    }
    
    /// Load and validate image file
    private func loadImage(from path: String) throws -> Data {
        let url = URL(fileURLWithPath: path)
        
        guard FileManager.default.fileExists(atPath: path) else {
            throw NSError(domain: "TachikomaMultimodal", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Image file not found: \(path)"
            ])
        }
        
        let imageData = try Data(contentsOf: url)
        
        // Basic validation - check if it looks like an image
        let validHeaders = [
            [0xFF, 0xD8], // JPEG
            [0x89, 0x50, 0x4E, 0x47], // PNG
            [0x47, 0x49, 0x46], // GIF
            [0x42, 0x4D], // BMP
            [0x52, 0x49, 0x46, 0x46] // WebP
        ]
        
        let isValidImage = validHeaders.contains { header in
            imageData.prefix(header.count).elementsEqual(header.map { UInt8($0) })
        }
        
        if !isValidImage {
            TerminalOutput.print("⚠️ Warning: File doesn't appear to be a standard image format", color: .yellow)
        }
        
        if verbose {
            TerminalOutput.print("📸 Loaded image: \(imageData.count) bytes", color: .dim)
        }
        
        return imageData
    }
    
    /// Determine the final prompt to use
    private func determineFinalPrompt() -> String {
        if ocr {
            return "Extract all text from this image. Provide the text content as accurately as possible, maintaining formatting when relevant."
        } else if describe {
            return "Describe what you see in this image in detail. Include objects, people, text, colors, setting, and any other notable features."
        } else if let userPrompt = prompt {
            return userPrompt
        } else {
            return "Analyze this image and describe what you see."
        }
    }
    
    /// Analyze with a single provider
    private func analyzeSingleProvider(imageData: Data, imagePath: String, prompt: String, modelProvider: AIModelProvider, availableModels: [String]) async throws {
        let selectedModel = try selectVisionModel(from: availableModels)
        let model = try modelProvider.getModel(selectedModel)
        let providerName = getProviderName(from: selectedModel)
        
        TerminalOutput.print("🎯 Analyzing with: \(providerName)", color: .cyan)
        TerminalOutput.print("📸 Image: \(imagePath)", color: .dim)
        TerminalOutput.print("💭 Prompt: \(prompt)", color: .yellow)
        TerminalOutput.separator("─")
        
        let analysis = try await analyzeImageWithProvider(
            imageData: imageData,
            prompt: prompt,
            model: model,
            modelName: selectedModel
        )
        
        displaySingleAnalysis(analysis)
    }
    
    /// Compare vision across multiple providers
    private func compareVisionAcrossProviders(imageData: Data, imagePath: String, prompt: String, modelProvider: AIModelProvider, availableModels: [String]) async throws {
        let visionModels = getVisionCapableModels(availableModels)
        
        if visionModels.count < 2 {
            TerminalOutput.print("❌ Need at least 2 vision models for comparison. Available: \(visionModels.count)", color: .red)
            return
        }
        
        TerminalOutput.print("👁️ Comparing vision across \(visionModels.count) providers", color: .cyan)
        TerminalOutput.print("📸 Image: \(imagePath)", color: .dim)
        TerminalOutput.print("💭 Prompt: \(prompt)", color: .yellow)
        TerminalOutput.separator("═")
        
        var analyses: [VisionAnalysis] = []
        
        // Analyze with each provider concurrently
        try await withThrowingTaskGroup(of: VisionAnalysis.self) { group in
            for model in visionModels.prefix(4) { // Limit to 4 for display
                group.addTask {
                    let modelInstance = try modelProvider.getModel(model)
                    return try await self.analyzeImageWithProvider(
                        imageData: imageData,
                        prompt: prompt,
                        model: modelInstance,
                        modelName: model
                    )
                }
            }
            
            for try await analysis in group {
                analyses.append(analysis)
            }
        }
        
        // Sort by provider name for consistent display
        analyses.sort { $0.provider < $1.provider }
        
        displayComparisonResults(analyses)
    }
    
    /// Analyze image with a specific provider using multimodal capabilities
    private func analyzeImageWithProvider(imageData: Data, prompt: String, model: ModelInterface, modelName: String) async throws -> VisionAnalysis {
        let providerName = getProviderName(from: modelName)
        let startTime = Date()
        
        do {
            // Prepare the image for multimodal request
            let base64Image = imageData.base64EncodedString()
            
            // Create multimodal content combining text prompt and image
            // This demonstrates Tachikoma's unified multimodal interface
            let multimodalContent = MessageContent.multimodal([
                MessageContentPart(type: "text", text: prompt, imageUrl: nil),
                MessageContentPart(type: "image_url", text: nil, imageUrl: ImageContent(base64: base64Image))
            ])
            
            let request = ModelRequest(
                messages: [Message.user(content: multimodalContent)],
                tools: nil, // No function calling for vision analysis
                settings: ModelSettings(maxTokens: 1000)
            )
            
            let response = try await model.getResponse(request: request)
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            // Extract text content from response
            // Vision models return their analysis as text content
            let responseText = response.content.compactMap { item in
                if case let .outputText(text) = item {
                    return text
                }
                return nil
            }.joined()
            
            let finalResponseText = responseText.isEmpty ? "No response" : responseText
            let tokenCount = PerformanceMeasurement.estimateTokenCount(finalResponseText)
            
            return VisionAnalysis(
                provider: providerName,
                model: modelName,
                response: finalResponseText,
                duration: duration,
                tokenCount: tokenCount,
                wordCount: finalResponseText.split(separator: " ").count,
                confidenceScore: calculateConfidenceScore(finalResponseText),
                capabilities: getModelCapabilities(modelName)
            )
            
        } catch {
            return VisionAnalysis(
                provider: providerName,
                model: modelName,
                response: "",
                duration: 0,
                tokenCount: 0,
                wordCount: 0,
                confidenceScore: 0,
                capabilities: [],
                error: error.localizedDescription
            )
        }
    }
    
    /// Select a vision-capable model
    private func selectVisionModel(from availableModels: [String]) throws -> String {
        let visionModels = getVisionCapableModels(availableModels)
        
        if visionModels.isEmpty {
            throw NSError(domain: "TachikomaMultimodal", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No vision-capable models available. Need GPT-4V, Claude 3+, or LLaVA."
            ])
        }
        
        if let requestedProvider = provider {
            for model in visionModels {
                if getProviderName(from: model).lowercased().contains(requestedProvider.lowercased()) {
                    return model
                }
            }
            TerminalOutput.print("⚠️ Requested provider '\(requestedProvider)' not available for vision. Using default.", color: .yellow)
        }
        
        // Prefer high-quality vision models
        let visionPreferred = ["gpt-4o", "claude-opus-4-20250514", "claude-3-5-sonnet", "llava"]
        
        for preferred in visionPreferred {
            if visionModels.contains(preferred) {
                return preferred
            }
        }
        
        return visionModels.first!
    }
    
    /// Get vision-capable models from available models
    private func getVisionCapableModels(_ availableModels: [String]) -> [String] {
        return availableModels.filter { model in
            let lowercased = model.lowercased()
            return lowercased.contains("gpt-4o") ||
                   lowercased.contains("gpt-4-vision") ||
                   lowercased.contains("claude-3") ||
                   lowercased.contains("claude-4") ||
                   lowercased.contains("llava") ||
                   lowercased.contains("vision")
        }
    }
    
    /// Get model capabilities
    private func getModelCapabilities(_ model: String) -> [String] {
        let lowercased = model.lowercased()
        var capabilities: [String] = []
        
        // All vision models can do basic analysis
        capabilities.append("Vision")
        capabilities.append("OCR")
        capabilities.append("Description")
        
        // Model-specific capabilities
        if lowercased.contains("gpt-4o") {
            capabilities.append("Chart Analysis")
            capabilities.append("Code Reading")
            capabilities.append("Spatial Reasoning")
        }
        
        if lowercased.contains("claude") {
            capabilities.append("Document Analysis")
            capabilities.append("Artistic Analysis")
            capabilities.append("Technical Diagrams")
        }
        
        if lowercased.contains("llava") {
            capabilities.append("General Vision")
            capabilities.append("Scene Understanding")
        }
        
        return capabilities
    }
    
    /// Detect MIME type from image data
    private func detectMimeType(from data: Data) -> String {
        guard !data.isEmpty else { return "application/octet-stream" }
        
        if data.count >= 2 && data[0] == 0xFF && data[1] == 0xD8 {
            return "image/jpeg"
        } else if data.count >= 4 && data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 {
            return "image/png"
        } else if data.count >= 3 && data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46 {
            return "image/gif"
        } else if data.count >= 2 && data[0] == 0x42 && data[1] == 0x4D {
            return "image/bmp"
        } else if data.count >= 12 && data[8...11].elementsEqual([0x57, 0x45, 0x42, 0x50]) {
            return "image/webp"
        }
        
        return "image/jpeg" // Default fallback
    }
    
    /// Calculate confidence score based on response characteristics
    private func calculateConfidenceScore(_ response: String) -> Double {
        var score = 0.5 // Base score
        
        // Longer responses often indicate more detailed analysis
        if response.count > 100 {
            score += 0.1
        }
        if response.count > 300 {
            score += 0.1
        }
        
        // Specific details indicate confidence
        let specificWords = ["color", "text", "number", "person", "object", "background", "size", "position"]
        let mentionedSpecifics = specificWords.filter { response.lowercased().contains($0) }
        score += Double(mentionedSpecifics.count) * 0.05
        
        // Hedging language indicates lower confidence
        let hedgeWords = ["might", "possibly", "appears", "seems", "likely", "probably", "unclear"]
        let hedgeCount = hedgeWords.filter { response.lowercased().contains($0) }.count
        score -= Double(hedgeCount) * 0.05
        
        return min(max(score, 0.0), 1.0)
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
    
    /// Display single analysis result
    private func displaySingleAnalysis(_ analysis: VisionAnalysis) {
        let emoji = TerminalOutput.providerEmoji(analysis.provider)
        
        if let error = analysis.error {
            TerminalOutput.print("❌ \(emoji) \(analysis.provider) Error: \(error)", color: .red)
            return
        }
        
        TerminalOutput.print("\(emoji) \(analysis.provider) Analysis:", color: .bold)
        TerminalOutput.separator("─")
        TerminalOutput.print(analysis.response, color: .white)
        TerminalOutput.separator("─")
        
        displayAnalysisStats(analysis)
        
        if verbose {
            TerminalOutput.print("\n🔍 Model Capabilities:", color: .yellow)
            for capability in analysis.capabilities {
                TerminalOutput.print("  • \(capability)", color: .dim)
            }
        }
    }
    
    /// Display comparison results
    private func displayComparisonResults(_ analyses: [VisionAnalysis]) {
        let successful = analyses.filter { $0.error == nil }
        
        if successful.isEmpty {
            TerminalOutput.print("❌ All vision analyses failed", color: .red)
            return
        }
        
        // Display each analysis
        for analysis in analyses {
            let emoji = TerminalOutput.providerEmoji(analysis.provider)
            
            TerminalOutput.print("\(emoji) \(analysis.provider):", color: .bold)
            
            if let error = analysis.error {
                TerminalOutput.print("❌ Error: \(error)", color: .red)
            } else {
                // Show truncated response
                let preview = analysis.response.count > 200 ? 
                    String(analysis.response.prefix(200)) + "..." : 
                    analysis.response
                TerminalOutput.print(preview, color: .white)
                
                let stats = formatCompactStats(analysis)
                TerminalOutput.print(stats, color: .dim)
            }
            
            TerminalOutput.separator("─", length: 60)
        }
        
        // Summary comparison
        displayVisionComparisonSummary(successful)
    }
    
    /// Display analysis statistics
    private func displayAnalysisStats(_ analysis: VisionAnalysis) {
        let stats = [
            "⏱️ Duration: \(String(format: "%.2fs", analysis.duration))",
            "🔤 Tokens: \(analysis.tokenCount)",
            "📝 Words: \(analysis.wordCount)",
            "🎯 Confidence: \(String(format: "%.0f%%", analysis.confidenceScore * 100))"
        ]
        
        TerminalOutput.print(stats.joined(separator: " | "), color: .dim)
    }
    
    /// Format compact statistics for comparison
    private func formatCompactStats(_ analysis: VisionAnalysis) -> String {
        return "⏱️ \(String(format: "%.1fs", analysis.duration)) | 📝 \(analysis.wordCount) words | 🎯 \(String(format: "%.0f%%", analysis.confidenceScore * 100))"
    }
    
    /// Display vision comparison summary
    private func displayVisionComparisonSummary(_ analyses: [VisionAnalysis]) {
        TerminalOutput.separator("═")
        TerminalOutput.print("🏆 Vision Analysis Summary:", color: .bold)
        TerminalOutput.separator("─")
        
        // Find best performers
        let fastest = analyses.min(by: { $0.duration < $1.duration })!
        let mostDetailed = analyses.max(by: { $0.wordCount < $1.wordCount })!
        let mostConfident = analyses.max(by: { $0.confidenceScore < $1.confidenceScore })!
        
        TerminalOutput.print("⚡ Fastest: \(fastest.provider) (\(String(format: "%.1fs", fastest.duration)))", color: .green)
        TerminalOutput.print("📝 Most Detailed: \(mostDetailed.provider) (\(mostDetailed.wordCount) words)", color: .cyan)
        TerminalOutput.print("🎯 Most Confident: \(mostConfident.provider) (\(String(format: "%.0f%%", mostConfident.confidenceScore * 100)))", color: .yellow)
        
        // Response length comparison
        let avgLength = analyses.reduce(0) { $0 + $1.wordCount } / analyses.count
        TerminalOutput.print("📊 Average response: \(avgLength) words", color: .dim)
        
        TerminalOutput.separator("─")
        TerminalOutput.print("💡 Each provider has different strengths for vision tasks", color: .yellow)
    }
}

// MARK: - Supporting Types

/// Result of vision analysis
struct VisionAnalysis {
    let provider: String
    let model: String
    let response: String
    let duration: TimeInterval
    let tokenCount: Int
    let wordCount: Int
    let confidenceScore: Double
    let capabilities: [String]
    let error: String?
    
    init(provider: String, model: String, response: String, duration: TimeInterval, tokenCount: Int, wordCount: Int, confidenceScore: Double, capabilities: [String], error: String? = nil) {
        self.provider = provider
        self.model = model
        self.response = response
        self.duration = duration
        self.tokenCount = tokenCount
        self.wordCount = wordCount
        self.confidenceScore = confidenceScore
        self.capabilities = capabilities
        self.error = error
    }
}