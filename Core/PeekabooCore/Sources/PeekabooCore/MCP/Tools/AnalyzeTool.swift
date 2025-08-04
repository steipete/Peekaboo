import Foundation
import MCP
import os.log
import TachikomaCore

/// MCP tool for analyzing images with AI
public struct AnalyzeTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "AnalyzeTool")

    public let name = "analyze"

    public var description: String {
        """
        Analyzes a pre-existing image file from the local filesystem using a configured AI model.

        This tool is useful when an image already exists (e.g., previously captured, downloaded, or generated) and you
        need to understand its content, extract text, or answer specific questions about it.

        Capabilities:
        - Image Understanding: Provide any question about the image (e.g., "What objects are in this picture?",
          "Describe the scene.", "Is there a red car?").
        - Text Extraction (OCR): Ask the AI to extract text from the image (e.g., "What text is visible in this screenshot?").
        - Flexible AI Configuration: Can use server-default AI providers/models or specify a particular one per call
          via 'provider_config'.

        Example:
        If you have an image '/tmp/chart.png' showing a bar chart, you could ask:
        { "image_path": "/tmp/chart.png", "question": "Which category has the highest value in this bar chart?" }
        The AI will analyze the image and attempt to answer your question based on its visual content.
        Peekaboo MCP 3.0.0-beta.2 using anthropic/claude-opus-4-20250514, ollama/llava:latest
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "image_path": SchemaBuilder.string(
                    description: "Required. Absolute path to image file (.png, .jpg, .webp) to be analyzed."),
                "question": SchemaBuilder.string(
                    description: "Required. Question for the AI about the image."),
                "provider_config": SchemaBuilder.object(
                    properties: [
                        "type": SchemaBuilder.string(
                            description: "AI provider, default: auto. 'auto' uses server's PEEKABOO_AI_PROVIDERS environment preference.",
                            enum: ["auto", "ollama", "openai", "anthropic", "grok"],
                            default: "auto"),
                        "model": SchemaBuilder.string(
                            description: "Optional. Model name. If omitted, uses model from server's PEEKABOO_AI_PROVIDERS."),
                    ],
                    description: "Optional. Explicit provider/model. Validated against server's PEEKABOO_AI_PROVIDERS."),
            ],
            required: ["question"])
    }

    public init() {}

    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        // Get required parameters
        guard let imagePath = arguments.getString("image_path") else {
            return ToolResponse.error("Missing required parameter: image_path")
        }

        guard let question = arguments.getString("question") else {
            return ToolResponse.error("Missing required parameter: question")
        }

        // Validate image file extension and determine media type
        let fileExtension = (imagePath as NSString).pathExtension.lowercased()
        let supportedFormats = ["png", "jpg", "jpeg", "webp"]
        guard supportedFormats.contains(fileExtension) else {
            return ToolResponse
                .error("Unsupported image format: .\(fileExtension). Supported formats: .png, .jpg, .jpeg, .webp")
        }

        // Determine media type based on file extension
        let mediaType = switch fileExtension {
        case "png":
            "image/png"
        case "jpg", "jpeg":
            "image/jpeg"
        case "webp":
            "image/webp"
        default:
            "image/jpeg" // fallback
        }

        // Check if file exists
        let expandedPath = (imagePath as NSString).expandingTildeInPath
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: expandedPath) else {
            return ToolResponse.error("Image file not found: \(imagePath)")
        }

        // Check AI providers configuration
        guard let aiProviders = ProcessInfo.processInfo.environment["PEEKABOO_AI_PROVIDERS"],
              !aiProviders.isEmpty
        else {
            return ToolResponse
                .error("AI analysis not configured on this server. Set the PEEKABOO_AI_PROVIDERS environment variable.")
        }

        // Parse the AI providers to determine which to use
        let (modelName, providerType) = self.parseAIProviders(aiProviders)

        do {
            self.logger.info("Analyzing image with \(providerType ?? "auto")/\(modelName)")
            let startTime = Date()

            // Use the new API
            let analysisText = try await analyzeImageWithAI(
                imagePath: expandedPath,
                question: question,
                modelName: modelName,
                providerType: providerType)

            let duration = Date().timeIntervalSince(startTime)
            self.logger.info("Analysis completed in \(String(format: "%.2f", duration))s")

            // Create response with metadata
            let metadata: [String: Any] = [
                "model_used": "\(providerType ?? "unknown")/\(modelName)",
                "analysis_text": analysisText,
                "duration_seconds": String(format: "%.2f", duration),
            ]

            let timingMessage = "\n\n👻 Peekaboo: Analyzed image with \(providerType ?? "unknown")/\(modelName) in \(String(format: "%.2f", duration))s."

            return ToolResponse(
                content: [
                    .text(analysisText),
                    .text(timingMessage),
                ])

        } catch {
            self.logger.error("Analysis failed: \(error)")
            return ToolResponse.error("AI analysis failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    private func parseAIProviders(_ providers: String) -> (modelName: String, providerType: String?) {
        // Parse PEEKABOO_AI_PROVIDERS format: "provider/model,provider2/model2"
        let components = providers.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        if let firstProvider = components.first {
            let parts = firstProvider.split(separator: "/")
            if parts.count >= 2 {
                let provider = String(parts[0])
                let model = String(parts[1])
                return (model, provider)
            } else {
                // Just a model name
                return (String(firstProvider), nil)
            }
        }

        // Default fallback
        return ("claude-opus-4-20250514", "anthropic")
    }

    private func analyzeImageWithAI(
        imagePath: String,
        question: String,
        modelName: String,
        providerType: String?) async throws -> String
    {
        // Load and encode the image
        guard let imageData = try? Data(contentsOf: URL(fileURLWithPath: imagePath)) else {
            throw PeekabooError.invalidInput("Could not load image from path: \(imagePath)")
        }

        let base64Image = imageData.base64EncodedString()

        // Create the model using the new API
        let languageModel: LanguageModel
        if let providerType {
            switch providerType.lowercased() {
            case "anthropic":
                languageModel = .anthropic(.opus4)
            case "openai":
                languageModel = .openai(.gpt4o)
            case "grok":
                languageModel = .grok(.grok4)
            case "ollama":
                languageModel = .ollama(.llava)
            default:
                throw PeekabooError.invalidInput("Unknown provider type: \(providerType)")
            }
        } else {
            // Try to parse the model name into a LanguageModel
            languageModel = try self.parseModelName(modelName)
        }

        // Create the conversation with the image and question
        let imageContent = ModelMessage.ContentPart.ImageContent(data: base64Image, mimeType: "image/png")
        let messages = [ModelMessage.user(text: question, images: [imageContent])]

        // Use the global generateText function
        let result = try await generateText(
            model: languageModel,
            messages: messages,
            tools: nil,
            settings: .default,
            maxSteps: 1)

        return result.text
    }

    /// Parse a model name string into a LanguageModel enum
    private func parseModelName(_ modelName: String) throws -> LanguageModel {
        let lowercased = modelName.lowercased()

        // Claude models
        if lowercased.contains("claude") {
            if lowercased.contains("opus") {
                return .anthropic(.opus4)
            } else if lowercased.contains("sonnet") {
                return .anthropic(.sonnet35)
            } else if lowercased.contains("haiku") {
                return .anthropic(.haiku35)
            } else {
                return .anthropic(.opus4) // Default Claude
            }
        }

        // OpenAI models
        if lowercased.contains("gpt") || lowercased.contains("o3") || lowercased.contains("o4") {
            if lowercased.contains("o3") {
                return .openai(.o3)
            } else if lowercased.contains("o4") {
                return .openai(.o4Mini)
            } else if lowercased.contains("4o") {
                return .openai(.gpt4o)
            } else if lowercased.contains("gpt-4.1") {
                return .openai(.gpt41)
            } else {
                return .openai(.gpt4o) // Default GPT
            }
        }

        // Grok models
        if lowercased.contains("grok") {
            return .grok(.grok4)
        }

        // Ollama models
        if lowercased.contains("llama") || lowercased.contains("llava") || lowercased.contains("mistral") {
            if lowercased.contains("llava") {
                return .ollama(.llava)
            } else if lowercased.contains("llama3.3") {
                return .ollama(.llama33)
            } else if lowercased.contains("mistral") {
                return .ollama(.mistralNemo)
            } else {
                return .ollama(.llama33) // Default Ollama
            }
        }

        // Default fallback
        return .anthropic(.opus4)
    }
}
