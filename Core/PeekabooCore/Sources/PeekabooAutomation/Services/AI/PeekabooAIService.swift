import CoreGraphics
import Foundation
import ImageIO
import Tachikoma

private final class PeekabooCustomProviderModel: ModelProvider, @unchecked Sendable {
    enum Kind {
        case openai
        case anthropic
    }

    let providerID: String
    let resolvedModelID: String
    let kind: Kind
    let modelId: String
    let baseURL: String?
    let apiKey: String?
    let additionalHeaders: [String: String]
    let capabilities: ModelCapabilities

    init(
        providerID: String,
        resolvedModelID: String,
        kind: Kind,
        baseURL: String,
        apiKey: String?,
        additionalHeaders: [String: String],
        supportsVision: Bool)
    {
        self.providerID = providerID
        self.resolvedModelID = resolvedModelID
        self.kind = kind
        self.modelId = "\(providerID)/\(resolvedModelID)"
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.additionalHeaders = additionalHeaders
        self.capabilities = ModelCapabilities(
            supportsVision: supportsVision,
            supportsTools: true,
            supportsStreaming: true)
    }

    func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        switch self.kind {
        case .openai:
            try await self.openAICompatibleProvider().generateText(request: request)
        case .anthropic:
            try await self.anthropicCompatibleProvider().generateText(request: request)
        }
    }

    func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, any Error> {
        switch self.kind {
        case .openai:
            try await self.openAICompatibleProvider().streamText(request: request)
        case .anthropic:
            try await self.anthropicCompatibleProvider().streamText(request: request)
        }
    }

    private func compatibleConfiguration() -> TachikomaConfiguration {
        let configuration = TachikomaConfiguration(loadFromEnvironment: true)
        guard let apiKey, !apiKey.isEmpty else { return configuration }

        switch self.kind {
        case .openai:
            configuration.setAPIKey(apiKey, for: "openai_compatible")
        case .anthropic:
            configuration.setAPIKey(apiKey, for: "anthropic_compatible")
        }
        return configuration
    }

    private func openAICompatibleProvider() throws -> OpenAICompatibleProvider {
        try OpenAICompatibleProvider(
            modelId: self.resolvedModelID,
            baseURL: self.baseURL ?? "",
            configuration: self.compatibleConfiguration(),
            additionalHeaders: self.additionalHeaders)
    }

    private func anthropicCompatibleProvider() throws -> AnthropicCompatibleProvider {
        try AnthropicCompatibleProvider(
            modelId: self.resolvedModelID,
            baseURL: self.baseURL ?? "",
            configuration: self.compatibleConfiguration(),
            additionalHeaders: self.additionalHeaders)
    }
}

/// AI service for handling model interactions and AI-powered features
@MainActor
public final class PeekabooAIService {
    private let configuration: ConfigurationManager
    private let resolvedModels: [LanguageModel]
    private let defaultModel: LanguageModel

    /// Exposed for tests (internal)
    var resolvedDefaultModel: LanguageModel {
        self.defaultModel
    }

    public init(configuration: ConfigurationManager = .shared) {
        self.configuration = configuration
        TachikomaConfiguration.profileDirectoryName = ".peekaboo"
        _ = configuration.loadConfiguration()
        self.resolvedModels = Self.resolveAvailableModels(configuration: configuration)
        self.defaultModel = self.resolvedModels.first ?? .openai(.gpt51)
        // Rely on TachikomaConfiguration to load from env/credentials (profile set at startup)
    }

    public struct AnalysisResult: Sendable {
        public let provider: String
        public let model: String
        public let text: String
    }

    /// Analyze an image with a question using AI
    public func analyzeImage(imageData: Data, question: String, model: LanguageModel? = nil) async throws -> String {
        let result = try await self.analyzeImageDetailed(imageData: imageData, question: question, model: model)
        return result.text
    }

    /// Analyze an image with a question returning structured metadata
    public func analyzeImageDetailed(
        imageData: Data,
        question: String,
        model: LanguageModel? = nil) async throws -> AnalysisResult
    {
        // Analyze an image with a question returning structured metadata
        let selectedModel = model ?? self.defaultModel

        // Create a message with the image using Tachikoma's API
        let base64String = imageData.base64EncodedString()
        let imageContent = ModelMessage.ContentPart.ImageContent(data: base64String, mimeType: "image/png")
        let messages = [ModelMessage.user(text: question, images: [imageContent])]

        let response = try await Tachikoma.generateText(
            model: selectedModel,
            messages: messages,
            configuration: self.tachikomaConfiguration(for: selectedModel))

        let (provider, modelName) = Self.providerAndModelName(for: selectedModel)

        let normalizedText = Self.normalizeCoordinateTextIfNeeded(
            response.text,
            model: modelName,
            imageSize: Self.imageSize(from: imageData))

        return AnalysisResult(provider: provider, model: modelName, text: normalizedText)
    }

    /// Analyze an image file with a question
    public func analyzeImageFile(
        at path: String,
        question: String,
        model: LanguageModel? = nil) async throws -> String
    {
        // Load image data
        let url = URL(fileURLWithPath: path.replacingOccurrences(of: "~", with: NSHomeDirectory()))
        let imageData = try Data(contentsOf: url)

        return try await self.analyzeImage(imageData: imageData, question: question, model: model)
    }

    /// Analyze an image file returning structured metadata
    public func analyzeImageFileDetailed(
        at path: String,
        question: String,
        model: LanguageModel? = nil) async throws -> AnalysisResult
    {
        // Analyze an image file returning structured metadata
        let url = URL(fileURLWithPath: path.replacingOccurrences(of: "~", with: NSHomeDirectory()))
        let imageData = try Data(contentsOf: url)
        return try await self.analyzeImageDetailed(imageData: imageData, question: question, model: model)
    }

    /// Generate text from a prompt
    public func generateText(prompt: String, model: LanguageModel? = nil) async throws -> String {
        // Generate text from a prompt
        let selectedModel = model ?? self.defaultModel

        let messages = [
            ModelMessage.user(prompt),
        ]

        let response = try await Tachikoma.generateText(
            model: selectedModel,
            messages: messages,
            configuration: self.tachikomaConfiguration(for: selectedModel))

        return response.text
    }

    /// List available models
    public func availableModels() -> [LanguageModel] {
        self.resolvedModels
    }

    private static func parseProviderEntry(_ entry: String, configuration: ConfigurationManager) -> LanguageModel? {
        if let parsed = AIProviderParser.parse(entry) {
            let provider = parsed.provider.lowercased()
            let modelString = parsed.model

            let loose = LanguageModel.parse(from: modelString)

            switch provider {
            case "openai":
                if case .openai = loose { return loose }
                return .openai(.custom(modelString))
            case "anthropic":
                if case .anthropic = loose { return loose }
                return .anthropic(.custom(modelString))
            case "google", "gemini":
                if case .google = loose { return loose }
                return nil
            case "mistral":
                if case .mistral = loose { return loose }
                return nil
            case "groq":
                if case .groq = loose { return loose }
                return nil
            case "grok", "xai":
                if case .grok = loose { return loose }
                return .grok(.custom(modelString))
            case "ollama":
                // For Ollama, prefer preserving the exact model id string.
                // Heuristics for custom model capabilities live in Tachikoma (LanguageModel.Ollama).
                return .ollama(.custom(modelString))
            case "lmstudio":
                return .lmstudio(.custom(modelString))
            default:
                if let customModel = self.customProviderModel(
                    providerID: provider,
                    modelString: modelString,
                    configuration: configuration)
                {
                    return .custom(provider: customModel)
                }
                return nil
            }
        }

        // Back-compat: allow loose model strings without "provider/model"
        return LanguageModel.parse(from: entry)
    }

    private static func resolveAvailableModels(configuration: ConfigurationManager) -> [LanguageModel] {
        let providers = configuration.getAIProviders()
        let parsed = providers
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .compactMap { self.parseProviderEntry($0, configuration: configuration) }

        if !parsed.isEmpty { return parsed }

        // Fallback: prefer Anthropic if a key is present, else OpenAI
        if let key = configuration.getAnthropicAPIKey(), !key.isEmpty {
            return [.anthropic(.opus45)]
        }
        return [.openai(.gpt51), .anthropic(.opus45)]
    }

    private static func providerAndModelName(for model: LanguageModel) -> (provider: String, model: String) {
        switch model {
        case let .openai(m): ("openai", m.modelId)
        case let .anthropic(m): ("anthropic", m.modelId)
        case let .google(m): ("google", m.rawValue)
        case let .mistral(m): ("mistral", m.rawValue)
        case let .groq(m): ("groq", m.rawValue)
        case let .grok(m): ("grok", m.modelId)
        case let .ollama(m): ("ollama", m.modelId)
        case let .lmstudio(m): ("lmstudio", m.modelId)
        case let .azureOpenAI(deployment, _, _, _): ("azure-openai", deployment)
        case let .openRouter(modelId): ("openrouter", modelId)
        case let .together(modelId): ("together", modelId)
        case let .replicate(modelId): ("replicate", modelId)
        case let .openaiCompatible(modelId, _): ("openai-compatible", modelId)
        case let .anthropicCompatible(modelId, _): ("anthropic-compatible", modelId)
        case let .custom(provider):
            if let peekabooProvider = provider as? PeekabooCustomProviderModel {
                (peekabooProvider.providerID, peekabooProvider.resolvedModelID)
            } else {
                ("custom", provider.modelId)
            }
        }
    }

    private func tachikomaConfiguration(for model: LanguageModel) -> TachikomaConfiguration {
        guard case let .custom(provider) = model,
              let peekabooProvider = provider as? PeekabooCustomProviderModel
        else {
            return .current
        }

        let configuration = TachikomaConfiguration(loadFromEnvironment: true)
        guard let apiKey = peekabooProvider.apiKey, !apiKey.isEmpty else {
            return configuration
        }

        switch peekabooProvider.kind {
        case .openai:
            configuration.setAPIKey(apiKey, for: "openai_compatible")
        case .anthropic:
            configuration.setAPIKey(apiKey, for: "anthropic_compatible")
        }
        return configuration
    }

    private static func customProviderModel(
        providerID: String,
        modelString: String,
        configuration: ConfigurationManager) -> PeekabooCustomProviderModel?
    {
        guard let provider = configuration.getCustomProvider(id: providerID),
              provider.enabled
        else {
            return nil
        }

        let model = provider.models?[modelString]
        let resolvedModelID = model?.name ?? modelString
        let kind: PeekabooCustomProviderModel.Kind = switch provider.type {
        case .openai: .openai
        case .anthropic: .anthropic
        }

        CustomProviderRegistry.shared.loadFromProfile()

        return PeekabooCustomProviderModel(
            providerID: providerID,
            resolvedModelID: resolvedModelID,
            kind: kind,
            baseURL: provider.options.baseURL,
            apiKey: self.resolveCredential(provider.options.apiKey, configuration: configuration),
            additionalHeaders: provider.options.headers ?? [:],
            supportsVision: model?.supportsVision ?? true)
    }

    private static func resolveCredential(_ reference: String, configuration: ConfigurationManager) -> String? {
        guard reference.hasPrefix("{env:"), reference.hasSuffix("}") else {
            return reference
        }

        let variableName = String(reference.dropFirst(5).dropLast(1))
        if let environmentValue = ProcessInfo.processInfo.environment[variableName] {
            return environmentValue
        }
        return configuration.credentialValue(for: variableName)
    }

    nonisolated static func normalizeCoordinateTextIfNeeded(
        _ text: String,
        model: String,
        imageSize: CGSize?) -> String
    {
        guard self.modelUsesNormalizedThousandCoordinates(model),
              let imageSize,
              imageSize.width > 0,
              imageSize.height > 0
        else {
            return text
        }

        let nsText = text as NSString
        let numberPattern = #"(-?\d+(?:\.\d+)?)"#
        let pattern = #"\[\s*"# +
            numberPattern +
            #"\s*,\s*"# +
            numberPattern +
            #"\s*,\s*"# +
            numberPattern +
            #"\s*,\s*"# +
            numberPattern +
            #"\s*\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).reversed()
        var result = text
        for match in matches {
            let values = (1...4).compactMap { index -> Double? in
                Double(nsText.substring(with: match.range(at: index)))
            }
            guard values.count == 4,
                  values.allSatisfy({ (0.0...1000.0).contains($0) }),
                  values[2] > values[0],
                  values[3] > values[1]
            else {
                continue
            }

            let converted = [
                Int((values[0] * Double(imageSize.width) / 1000.0).rounded()),
                Int((values[1] * Double(imageSize.height) / 1000.0).rounded()),
                Int((values[2] * Double(imageSize.width) / 1000.0).rounded()),
                Int((values[3] * Double(imageSize.height) / 1000.0).rounded()),
            ]
            let original = nsText.substring(with: match.range)
            let replacement = "[\(converted[0]), \(converted[1]), \(converted[2]), \(converted[3])] " +
                "(converted from GLM normalized \(original))"

            if let range = Range(match.range, in: result) {
                result.replaceSubrange(range, with: replacement)
            }
        }

        return result
    }

    private nonisolated static func modelUsesNormalizedThousandCoordinates(_ model: String) -> Bool {
        model.lowercased().contains("glm")
    }

    private nonisolated static func imageSize(from imageData: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat
        else {
            return nil
        }

        return CGSize(width: width, height: height)
    }
}
