import Foundation
@_exported import Logging

// All types are already public and available when importing Tachikoma
// Swift Package Manager automatically makes all public types available
// No need for explicit re-exports since they're in the same module

/// Tachikoma - A comprehensive Swift package for AI model integration
///
/// Tachikoma provides a unified interface for connecting to various AI providers
/// including OpenAI, Anthropic, Grok (xAI), Ollama, and custom endpoints.
/// It supports both streaming and non-streaming responses, tool calling,
/// multimodal inputs, and configuration management.
///
/// Named after the AI entity from Ghost in the Shell, Tachikoma embodies
/// the cyberpunk aesthetic of autonomous AI systems.

public final class Tachikoma: @unchecked Sendable {
    public static let shared = Tachikoma()
    
    private let logger: Logger
    
    private init() {
        self.logger = Logger(label: "build.tachikoma")
    }
    
    /// Get the shared logger instance
    public var log: Logger {
        logger
    }
    
    /// Get a model instance for the specified model name
    /// - Parameter modelName: The model identifier (e.g., "gpt-4.1", "claude-opus-4", "provider-id/model-name")
    /// - Returns: A model instance conforming to ModelInterface
    /// - Throws: TachikomaError if the model is not available or configuration is invalid
    public func getModel(_ modelName: String) async throws -> any ModelInterface {
        return try await ModelProvider.shared.getModel(modelName: modelName)
    }
    
    /// Configure OpenAI provider with specific settings
    /// - Parameter configuration: OpenAI configuration
    public func configureOpenAI(_ configuration: ProviderConfiguration.OpenAI) async {
        await ModelProvider.shared.configureOpenAI(configuration)
    }
    
    /// Configure Anthropic provider with specific settings
    /// - Parameter configuration: Anthropic configuration
    public func configureAnthropic(_ configuration: ProviderConfiguration.Anthropic) async {
        await ModelProvider.shared.configureAnthropic(configuration)
    }
    
    /// Configure Ollama provider with specific settings
    /// - Parameter configuration: Ollama configuration
    public func configureOllama(_ configuration: ProviderConfiguration.Ollama) async {
        await ModelProvider.shared.configureOllama(configuration)
    }
    
    /// Configure Grok provider with specific settings
    /// - Parameter configuration: Grok configuration
    public func configureGrok(_ configuration: ProviderConfiguration.Grok) async {
        await ModelProvider.shared.configureGrok(configuration)
    }
    
    /// Set up all providers from environment variables
    /// - Throws: TachikomaError if setup fails
    public func setupFromEnvironment() async throws {
        try await ModelProvider.shared.setupFromEnvironment()
    }
    
    /// List all available models from configured providers
    /// - Returns: Array of available model identifiers
    public func availableModels() async -> [String] {
        return await ModelProvider.shared.listModels()
    }
    
    /// Clear all cached model instances
    public func clearModelCache() async {
        await ModelProvider.shared.clearCache()
    }
    
    /// Register a custom model factory
    /// - Parameters:
    ///   - modelName: The model name to register
    ///   - factory: Factory closure that creates the model instance
    public func registerModel(
        name modelName: String,
        factory: @escaping @Sendable () throws -> any ModelInterface) async
    {
        await ModelProvider.shared.register(modelName: modelName, factory: factory)
    }
}