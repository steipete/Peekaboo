import Foundation
import MCP
import os.log
import Tachikoma

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
            // Read the image file
            let imageData = try Data(contentsOf: URL(fileURLWithPath: expandedPath))
            let base64String = imageData.base64EncodedString()

            // Get or create model instance
            let model = try await getOrCreateModel(modelName: modelName, providerType: providerType)

            // Create a request with the image
            let imageContent = ImageContent(base64: base64String)
            let messageContent = MessageContent.multimodal([
                MessageContentPart(type: "text", text: question),
                MessageContentPart(type: "image", imageUrl: imageContent),
            ])

            // Create messages array - avoid ambiguity by not using type annotation
            let userMessage = Message.user(content: messageContent)
            let messages = [userMessage]

            let settings = ModelSettings(
                modelName: modelName,
                temperature: 0.7,
                maxTokens: 4096)

            let request = ModelRequest(
                messages: messages,
                tools: nil,
                settings: settings)

            self.logger.info("Analyzing image with \(providerType ?? "auto")/\(modelName)")
            let startTime = Date()

            // Get the response
            let response = try await model.getResponse(request: request)
            let analysisText: String
            if case .outputText(let text) = response.content.first {
                analysisText = text
            } else {
                analysisText = "No response received"
            }

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

    private func getOrCreateModel(modelName: String, providerType: String?) async throws -> any ModelInterface {
        // Use Tachikoma API which handles actor isolation properly
        do {
            return try await Tachikoma.shared.getModel(modelName)
        } catch {
            // If not found, try to create based on provider type
            if let providerType {
                switch providerType.lowercased() {
                case "anthropic":
                    guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
                        throw PeekabooError.authenticationFailed("ANTHROPIC_API_KEY not set")
                    }
                    throw PeekabooError.invalidInput("AnthropicModel not yet implemented")

                case "openai":
                    guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
                        throw PeekabooError.authenticationFailed("OPENAI_API_KEY not set")
                    }
                    throw PeekabooError.invalidInput("OpenAIModel not yet implemented")

                case "grok":
                    guard let apiKey = ProcessInfo.processInfo.environment["X_AI_API_KEY"] ??
                        ProcessInfo.processInfo.environment["XAI_API_KEY"]
                    else {
                        throw PeekabooError.authenticationFailed("X_AI_API_KEY or XAI_API_KEY not set")
                    }
                    throw PeekabooError.invalidInput("GrokModel not yet implemented")

                case "ollama":
                    let baseURLString = ProcessInfo.processInfo.environment["PEEKABOO_OLLAMA_BASE_URL"] ?? "http://localhost:11434"
                    guard let baseURL = URL(string: baseURLString) else {
                        throw PeekabooError.invalidInput("Invalid Ollama base URL: \(baseURLString)")
                    }
                    throw PeekabooError.invalidInput("OllamaModel not yet implemented")

                default:
                    throw PeekabooError.invalidInput("Unknown provider type: \(providerType)")
                }
            }

            // Final fallback - try to guess based on model name
            if modelName.contains("claude") {
                guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
                    throw PeekabooError.authenticationFailed("ANTHROPIC_API_KEY not set")
                }
                throw PeekabooError.invalidInput("AnthropicModel not yet implemented")
            } else if modelName.contains("gpt") || modelName.contains("o3") || modelName.contains("o4") {
                guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
                    throw PeekabooError.authenticationFailed("OPENAI_API_KEY not set")
                }
                throw PeekabooError.invalidInput("OpenAIModel not yet implemented")
            } else {
                // Assume Ollama for unknown models
                let baseURLString = ProcessInfo.processInfo.environment["PEEKABOO_OLLAMA_BASE_URL"] ?? "http://localhost:11434"
                guard let baseURL = URL(string: baseURLString) else {
                    throw PeekabooError.invalidInput("Invalid Ollama base URL: \(baseURLString)")
                }
                throw PeekabooError.invalidInput("OllamaModel not yet implemented")
            }
        }
    }
}
