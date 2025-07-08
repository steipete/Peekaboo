import Foundation
import os.log

/// Default implementation of AI provider service
public final class AIProviderService: AIProviderServiceProtocol, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.steipete.PeekabooCore", category: "AIProvider")
    private let providers: [AIProvider]
    
    public init() {
        // Get providers from environment or configuration
        let providerString = ProcessInfo.processInfo.environment["PEEKABOO_AI_PROVIDERS"]
        self.providers = AIProviderFactory.createProviders(from: providerString)
        
        if providers.isEmpty {
            logger.warning("No AI providers configured. Set PEEKABOO_AI_PROVIDERS environment variable.")
        } else {
            logger.info("Initialized with \(self.providers.count) AI provider(s): \(self.providers.map { $0.name }.joined(separator: ", "))")
        }
    }
    
    public func analyzeImage(at path: String, prompt: String) async throws -> AIAnalysisResult {
        // Find first available provider
        guard let provider = await AIProviderFactory.findAvailableProvider(from: providers) else {
            throw AIProviderError.notConfigured("No AI providers are currently available")
        }
        
        // Read and encode image
        let imageData = try Data(contentsOf: URL(fileURLWithPath: path))
        let base64String = imageData.base64EncodedString()
        
        logger.info("Analyzing image with \(provider.name)/\(provider.model)")
        
        // Perform analysis
        let analysis = try await provider.analyze(imageBase64: base64String, question: prompt)
        
        return AIAnalysisResult(
            provider: provider.name,
            model: provider.model,
            analysis: analysis
        )
    }
    
    public func getProvidersStatus() async -> [AIProviderStatus] {
        var statuses: [AIProviderStatus] = []
        for provider in providers {
            let status = await provider.checkAvailability()
            statuses.append(status)
        }
        return statuses
    }
    
    public var isAvailable: Bool {
        get async {
            for provider in providers {
                if await provider.isAvailable {
                    return true
                }
            }
            return false
        }
    }
}