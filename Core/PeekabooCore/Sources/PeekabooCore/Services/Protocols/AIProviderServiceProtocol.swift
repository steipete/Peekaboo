import Foundation

/// Service protocol for AI-based image analysis
public protocol AIProviderServiceProtocol: Sendable {
    /// Analyze an image with AI using the configured providers
    /// - Parameters:
    ///   - path: Path to the image file
    ///   - prompt: The analysis prompt/question
    /// - Returns: Analysis result including provider information
    func analyzeImage(at path: String, prompt: String) async throws -> AIAnalysisResult
    
    /// Get the status of all configured AI providers
    func getProvidersStatus() async -> [AIProviderStatus]
    
    /// Check if any AI provider is available
    var isAvailable: Bool { get async }
}

/// Result of AI image analysis
public struct AIAnalysisResult: Sendable {
    public let provider: String
    public let model: String
    public let analysis: String
    
    public init(provider: String, model: String, analysis: String) {
        self.provider = provider
        self.model = model
        self.analysis = analysis
    }
}