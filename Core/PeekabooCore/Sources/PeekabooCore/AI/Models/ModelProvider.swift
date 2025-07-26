import Foundation

// MARK: - Model Provider

/// Singleton provider for managing model instances
public actor ModelProvider {
    /// Shared instance
    public static let shared = ModelProvider()
    
    /// Registered model factories
    private var modelFactories: [String: () throws -> any ModelInterface] = [:]
    
    /// Model instance cache
    private var modelCache: [String: any ModelInterface] = [:]
    
    private init() {
        // Register default models
        Task {
            await registerDefaultModels()
        }
    }
    
    // MARK: - Public Methods
    
    /// Register a model factory
    /// - Parameters:
    ///   - name: The model name
    ///   - factory: Factory closure that creates the model
    public func register(
        modelName: String,
        factory: @escaping () throws -> any ModelInterface
    ) {
        modelFactories[modelName] = factory
        // Clear cache for this model
        modelCache.removeValue(forKey: modelName)
    }
    
    /// Get a model by name
    /// - Parameter modelName: The name of the model
    /// - Returns: A model instance
    /// - Throws: ModelError if model not found
    public func getModel(modelName: String) throws -> any ModelInterface {
        // Check cache first
        if let cached = modelCache[modelName] {
            return cached
        }
        
        // Try to create model
        guard let factory = modelFactories[modelName] else {
            throw ModelError.modelNotFound(modelName)
        }
        
        let model = try factory()
        
        // Cache the model
        modelCache[modelName] = model
        
        return model
    }
    
    /// List all registered models
    public func listModels() -> [String] {
        Array(modelFactories.keys).sorted()
    }
    
    /// Clear model cache
    public func clearCache() {
        modelCache.removeAll()
    }
    
    /// Unregister a model
    public func unregister(modelName: String) {
        modelFactories.removeValue(forKey: modelName)
        modelCache.removeValue(forKey: modelName)
    }
    
    // MARK: - Private Methods
    
    private func registerDefaultModels() {
        // Register OpenAI models
        registerOpenAIModels()
        
        // Future: Register other providers
        // registerAnthropicModels()
        // registerOllamaModels()
    }
    
    private func registerOpenAIModels() {
        let models = [
            // GPT-4o series
            "gpt-4o",
            "gpt-4o-mini",
            
            // GPT-4.1 series
            "gpt-4.1",
            "gpt-4.1-mini",
            
            // o3 series (Responses API only)
            "o3",
            "o3-mini",
            "o3-pro",
            
            // o4 series (Responses API only)
            "o4-mini"
        ]
        
        for modelName in models {
            register(modelName: modelName) {
                guard let apiKey = self.getOpenAIAPIKey() else {
                    throw ModelError.authenticationFailed
                }
                
                return OpenAIModel(apiKey: apiKey)
            }
        }
    }
    
    private func getOpenAIAPIKey() -> String? {
        // Check environment variable
        if let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            return apiKey
        }
        
        // Check credentials file
        let credentialsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".peekaboo")
            .appendingPathComponent("credentials")
        
        if let credentials = try? String(contentsOf: credentialsPath) {
            for line in credentials.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("OPENAI_API_KEY=") {
                    return String(trimmed.dropFirst("OPENAI_API_KEY=".count))
                }
            }
        }
        
        return nil
    }
}

// MARK: - Model Provider Configuration

/// Configuration for model providers
public struct ModelProviderConfig {
    /// OpenAI configuration
    public struct OpenAI {
        public let apiKey: String
        public let organizationId: String?
        public let baseURL: URL?
        
        public init(
            apiKey: String,
            organizationId: String? = nil,
            baseURL: URL? = nil
        ) {
            self.apiKey = apiKey
            self.organizationId = organizationId
            self.baseURL = baseURL
        }
    }
    
    /// Anthropic configuration (future)
    public struct Anthropic {
        public let apiKey: String
        public let baseURL: URL?
        
        public init(
            apiKey: String,
            baseURL: URL? = nil
        ) {
            self.apiKey = apiKey
            self.baseURL = baseURL
        }
    }
    
    /// Ollama configuration (future)
    public struct Ollama {
        public let baseURL: URL
        
        public init(baseURL: URL = URL(string: "http://localhost:11434")!) {
            self.baseURL = baseURL
        }
    }
}

// MARK: - Model Provider Extensions

extension ModelProvider {
    /// Configure OpenAI models with specific settings
    public func configureOpenAI(_ config: ModelProviderConfig.OpenAI) {
        let models = [
            // GPT-4o series
            "gpt-4o",
            "gpt-4o-mini",
            
            // GPT-4.1 series
            "gpt-4.1",
            "gpt-4.1-mini",
            
            // o3 series (Responses API only)
            "o3",
            "o3-mini",
            "o3-pro",
            
            // o4 series (Responses API only)
            "o4-mini"
        ]
        
        for modelName in models {
            register(modelName: modelName) {
                OpenAIModel(
                    apiKey: config.apiKey,
                    baseURL: config.baseURL ?? URL(string: "https://api.openai.com/v1")!,
                    organizationId: config.organizationId
                )
            }
        }
    }
    
    /// Quick setup with API key from environment
    public func setupFromEnvironment() async throws {
        if let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            configureOpenAI(ModelProviderConfig.OpenAI(apiKey: apiKey))
        }
        
        // Future: Add other providers
        // if let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
        //     configureAnthropic(ModelProviderConfig.Anthropic(apiKey: apiKey))
        // }
    }
}