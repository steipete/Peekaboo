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
        // Look up model by name
        
        // Check cache first
        if let cached = modelCache[modelName] {
            // Return cached model
            return cached
        }
        
        // Try exact match first
        if let factory = modelFactories[modelName] {
            // Create new model instance
            let model = try factory()
            modelCache[modelName] = model
            return model
        }
        
        // Try lenient matching for shortened names
        if let resolvedName = resolveLenientModelName(modelName),
           let factory = modelFactories[resolvedName] {
            // Create model with resolved name
            let model = try factory()
            // Cache with both original and resolved names
            modelCache[modelName] = model
            modelCache[resolvedName] = model
            return model
        }
        
        // Model not found in registry
        throw ModelError.modelNotFound(modelName)
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
        
        // Register Anthropic models
        registerAnthropicModels()
        
        // Register Grok models
        registerGrokModels()
        
        // Register Ollama models
        registerOllamaModels()
    }
    
    /// Resolve lenient model names to their full versions
    private func resolveLenientModelName(_ modelName: String) -> String? {
        let lowercased = modelName.lowercased()
        
        // Claude model shortcuts
        if lowercased == "claude-4-opus" || lowercased == "claude-opus-4" || lowercased == "claude-opus" {
            return "claude-opus-4-20250514"
        }
        if lowercased == "claude-4-sonnet" || lowercased == "claude-sonnet-4" || lowercased == "claude-sonnet" {
            return "claude-sonnet-4-20250514"
        }
        if lowercased == "claude-3.7-sonnet" || lowercased == "claude-3-7-sonnet" || lowercased == "claude-sonnet-3.7" {
            return "claude-3-7-sonnet" // Specific model ID TBD
        }
        if lowercased == "claude-3.5-sonnet" || lowercased == "claude-3-5-sonnet" || lowercased == "claude-sonnet-3.5" {
            return "claude-3-5-sonnet"
        }
        if lowercased == "claude-3.5-haiku" || lowercased == "claude-3-5-haiku" || lowercased == "claude-haiku-3.5" {
            return "claude-3-5-haiku"
        }
        if lowercased == "claude-3.5-opus" || lowercased == "claude-3-5-opus" || lowercased == "claude-opus-3.5" {
            return "claude-3-5-opus"
        }
        if lowercased == "claude" {
            return "claude-opus-4-20250514" // Default to Claude Opus 4
        }
        
        // OpenAI model shortcuts
        if lowercased == "gpt4" || lowercased == "gpt-4" {
            return "gpt-4.1"
        }
        if lowercased == "gpt4-mini" || lowercased == "gpt-4-mini" {
            return "gpt-4.1-mini"
        }
        if lowercased == "gpt" {
            return "gpt-4.1" // Default to latest GPT
        }
        
        // Grok model shortcuts
        if lowercased == "grok" || lowercased == "grok4" || lowercased == "grok-4" {
            return "grok-4-0709"
        }
        if lowercased == "grok3" || lowercased == "grok-3" {
            return "grok-3"
        }
        if lowercased == "grok2" || lowercased == "grok-2" {
            return "grok-2-vision-1212"
        }
        
        // Check if it's a partial match for any registered model
        let registeredModels = Array(modelFactories.keys)
        for model in registeredModels {
            if model.lowercased().contains(lowercased) || lowercased.contains(model.lowercased()) {
                return model
            }
        }
        
        return nil
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
    
    private func registerAnthropicModels() {
        // Map of model names to their actual IDs
        let modelMappings: [String: String] = [
            // Claude 4 series (Latest - May 2025)
            "claude-opus-4-20250514": "claude-opus-4-20250514",
            "claude-opus-4-20250514-thinking": "claude-opus-4-20250514-thinking",
            "claude-sonnet-4-20250514": "claude-sonnet-4-20250514",
            "claude-sonnet-4-20250514-thinking": "claude-sonnet-4-20250514-thinking",
            
            // Claude 3.7 series (February 2025)
            "claude-3-7-sonnet": "claude-3-7-sonnet", // Actual model ID TBD
            
            // Claude 3.5 series (Still available)
            "claude-3-5-haiku": "claude-3-5-haiku",
            "claude-3-5-sonnet": "claude-3-5-sonnet",
            "claude-3-5-opus": "claude-3-5-opus"
        ]
        
        for (alias, actualModelId) in modelMappings {
            register(modelName: alias) {
                guard let apiKey = self.getAnthropicAPIKey() else {
                    throw ModelError.authenticationFailed
                }
                
                return AnthropicModel(apiKey: apiKey, modelName: actualModelId)
            }
        }
    }
    
    private func getAnthropicAPIKey() -> String? {
        // Check environment variable
        if let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
            return apiKey
        }
        
        // Check credentials file
        let credentialsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".peekaboo")
            .appendingPathComponent("credentials")
        
        if let credentials = try? String(contentsOf: credentialsPath) {
            for line in credentials.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("ANTHROPIC_API_KEY=") {
                    return String(trimmed.dropFirst("ANTHROPIC_API_KEY=".count))
                }
            }
        }
        
        return nil
    }
    
    private func registerGrokModels() {
        let models = [
            // Grok 4 series
            "grok-4-0709",
            
            // Grok 3 series
            "grok-3",
            "grok-3-mini",
            "grok-3-fast",
            "grok-3-mini-fast",
            
            // Grok 2 series
            "grok-2-vision-1212",
            "grok-2-image-1212"
        ]
        
        for modelName in models {
            register(modelName: modelName) {
                guard let apiKey = self.getGrokAPIKey() else {
                    throw ModelError.authenticationFailed
                }
                
                return GrokModel(apiKey: apiKey)
            }
        }
    }
    
    private func getGrokAPIKey() -> String? {
        // Check environment variables (both variants)
        if let apiKey = ProcessInfo.processInfo.environment["X_AI_API_KEY"] {
            return apiKey
        }
        if let apiKey = ProcessInfo.processInfo.environment["XAI_API_KEY"] {
            return apiKey
        }
        
        // Check credentials file
        let credentialsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".peekaboo")
            .appendingPathComponent("credentials")
        
        if let credentials = try? String(contentsOf: credentialsPath) {
            for line in credentials.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("X_AI_API_KEY=") {
                    return String(trimmed.dropFirst("X_AI_API_KEY=".count))
                }
                if trimmed.hasPrefix("XAI_API_KEY=") {
                    return String(trimmed.dropFirst("XAI_API_KEY=".count))
                }
            }
        }
        
        return nil
    }
    
    private func registerOllamaModels() {
        // Common Ollama models
        let models = [
            "llava:latest",
            "llava",
            "llama2",
            "llama2:latest",
            "codellama",
            "codellama:latest",
            "mistral",
            "mistral:latest",
            "mixtral",
            "mixtral:latest",
            "neural-chat",
            "neural-chat:latest",
            "gemma",
            "gemma:latest"
        ]
        
        // Get base URL from environment or config
        let baseURLString = ProcessInfo.processInfo.environment["PEEKABOO_OLLAMA_BASE_URL"] ?? "http://localhost:11434"
        guard let baseURL = URL(string: baseURLString) else { return }
        
        for modelName in models {
            register(modelName: modelName) {
                OllamaModel(modelName: modelName, baseURL: baseURL)
            }
        }
        
        // Successfully registered Ollama models
        
        // Also register any model with ollama prefix dynamically
        // This allows using any Ollama model without pre-registration
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
    
    /// Grok/xAI configuration
    public struct Grok {
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
    
    /// Configure Anthropic models with specific settings
    public func configureAnthropic(_ config: ModelProviderConfig.Anthropic) {
        // Map of model names to their actual IDs
        let modelMappings: [String: String] = [
            // Claude 4 series (Latest - May 2025)
            "claude-opus-4-20250514": "claude-opus-4-20250514",
            "claude-opus-4-20250514-thinking": "claude-opus-4-20250514-thinking",
            "claude-sonnet-4-20250514": "claude-sonnet-4-20250514",
            "claude-sonnet-4-20250514-thinking": "claude-sonnet-4-20250514-thinking",
            
            // Claude 3.7 series (February 2025)
            "claude-3-7-sonnet": "claude-3-7-sonnet", // Actual model ID TBD
            
            // Claude 3.5 series (Still available)
            "claude-3-5-haiku": "claude-3-5-haiku",
            "claude-3-5-sonnet": "claude-3-5-sonnet",
            "claude-3-5-opus": "claude-3-5-opus"
        ]
        
        for (alias, actualModelId) in modelMappings {
            register(modelName: alias) {
                AnthropicModel(
                    apiKey: config.apiKey,
                    baseURL: config.baseURL ?? URL(string: "https://api.anthropic.com/v1")!,
                    modelName: actualModelId
                )
            }
        }
    }
    
    /// Configure Ollama models with specific settings
    public func configureOllama(_ config: ModelProviderConfig.Ollama) {
        let models = [
            "llava:latest",
            "llava",
            "llama2",
            "llama2:latest", 
            "codellama",
            "codellama:latest",
            "mistral",
            "mistral:latest",
            "mixtral",
            "mixtral:latest",
            "neural-chat",
            "neural-chat:latest",
            "gemma",
            "gemma:latest"
        ]
        
        for modelName in models {
            register(modelName: modelName) {
                OllamaModel(modelName: modelName, baseURL: config.baseURL)
            }
        }
    }
    
    /// Configure Grok models with specific settings
    public func configureGrok(_ config: ModelProviderConfig.Grok) {
        let models = [
            // Grok 4 series
            "grok-4-0709",
            
            // Grok 3 series
            "grok-3",
            "grok-3-mini",
            "grok-3-fast",
            "grok-3-mini-fast",
            
            // Grok 2 series
            "grok-2-vision-1212",
            "grok-2-image-1212"
        ]
        
        for modelName in models {
            register(modelName: modelName) {
                GrokModel(
                    apiKey: config.apiKey,
                    baseURL: config.baseURL ?? URL(string: "https://api.x.ai/v1")!
                )
            }
        }
    }
    
    /// Quick setup with API key from environment
    public func setupFromEnvironment() async throws {
        if let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            configureOpenAI(ModelProviderConfig.OpenAI(apiKey: apiKey))
        }
        
        if let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
            configureAnthropic(ModelProviderConfig.Anthropic(apiKey: apiKey))
        }
        
        // Configure Ollama (no API key needed)
        let ollamaBaseURL = ProcessInfo.processInfo.environment["PEEKABOO_OLLAMA_BASE_URL"] ?? "http://localhost:11434"
        if let baseURL = URL(string: ollamaBaseURL) {
            configureOllama(ModelProviderConfig.Ollama(baseURL: baseURL))
        }
        
        // Configure Grok with various API key options
        if let apiKey = ProcessInfo.processInfo.environment["X_AI_API_KEY"] ?? 
                        ProcessInfo.processInfo.environment["XAI_API_KEY"] {
            configureGrok(ModelProviderConfig.Grok(apiKey: apiKey))
        }
    }
}