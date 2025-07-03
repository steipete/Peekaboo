import ArgumentParser
import Foundation

struct AnalyzeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "analyze",
        abstract: "Analyze images using AI vision models",
        discussion: """
            SYNOPSIS:
              peekaboo analyze IMAGE_PATH QUESTION [--provider PROVIDER] [--model MODEL] [--json-output]

            DESCRIPTION:
              Analyzes images using AI vision models to answer questions about
              visual content. Supports both local and cloud-based AI providers.

            EXAMPLES:
              peekaboo analyze screenshot.png "What's in this image?"
              peekaboo analyze error.png "What error message is shown?"
              peekaboo analyze ui.png "Describe the layout"
              
              # Use specific providers
              peekaboo analyze diagram.png "Explain this diagram" --provider openai
              peekaboo analyze photo.png "What objects are visible?" --provider ollama
              
              # Use specific models
              peekaboo analyze chart.png "What data is shown?" --model gpt-4o
              peekaboo analyze ui.png "Find buttons" --provider ollama --model llava:latest
              
              # Combine with capture
              peekaboo --mode frontmost --path /tmp/active.png && \
                peekaboo analyze /tmp/active.png "What application is this?"
              
              # JSON output for scripting
              peekaboo analyze error.png "Is there an error?" --json-output | \
                jq -r '.data.analysis_text'

            COMMON USE CASES:
              # UI debugging
              peekaboo analyze screenshot.png "What errors or warnings are visible?"
              
              # Accessibility testing
              peekaboo analyze app.png "Describe this interface for a visually impaired user"
              
              # Documentation
              peekaboo analyze diagram.png "Create a text description of this diagram"
              
              # Automated testing
              peekaboo analyze test-result.png "Did the test pass or fail?"

            AI PROVIDERS:
              auto    Automatically select first available provider (default)
              openai  OpenAI GPT-4 Vision (cloud-based, high quality)
              ollama  Local Ollama models (privacy-focused, offline capable)

            SUPPORTED FORMATS:
              PNG, JPG, JPEG, WebP

            ENVIRONMENT VARIABLES:
              PEEKABOO_AI_PROVIDERS      Comma-separated list of providers/models
                                         Example: "openai/gpt-4o,ollama/llava:latest"
                                         
              OPENAI_API_KEY             Required for OpenAI provider
              PEEKABOO_OLLAMA_BASE_URL   Ollama server URL (default: http://localhost:11434)

            EXIT STATUS:
              0  Analysis completed successfully
              1  Analysis failed (missing file, invalid format, API error)
            """
    )
    
    @Argument(help: ArgumentHelp("Path to the image file to analyze", valueName: "image-path"))
    var imagePath: String
    
    @Argument(help: ArgumentHelp("Question to ask about the image", valueName: "question"))
    var question: String
    
    @Option(name: .long, help: ArgumentHelp("AI provider to use: auto, openai, or ollama", valueName: "provider"))
    var provider: String = "auto"
    
    @Option(name: .long, help: ArgumentHelp("Specific AI model to use (e.g., gpt-4o, llava:latest)", valueName: "model"))
    var model: String?
    
    @Flag(name: .long, help: "Output results in JSON format for scripting")
    var jsonOutput = false
    
    func run() async throws {
        Logger.shared.setJsonOutputMode(jsonOutput)
        
        do {
            let result = try await performAnalysis()
            outputResults(result)
        } catch {
            handleError(error)
            throw ExitCode(1)
        }
    }
    
    private func performAnalysis() async throws -> AnalysisResult {
        // Validate image path
        let imagePath = URL(fileURLWithPath: self.imagePath)
        guard FileManager.default.fileExists(atPath: imagePath.path) else {
            throw AnalyzeError.fileNotFound(self.imagePath)
        }
        
        // Check file extension
        let validExtensions = ["png", "jpg", "jpeg", "webp"]
        guard validExtensions.contains(imagePath.pathExtension.lowercased()) else {
            throw AnalyzeError.unsupportedFormat(imagePath.pathExtension)
        }
        
        // Read image and convert to base64
        let imageData = try Data(contentsOf: imagePath)
        let base64String = imageData.base64EncodedString()
        
        // Get configured providers
        let aiProvidersEnv = ProcessInfo.processInfo.environment["PEEKABOO_AI_PROVIDERS"]
        let configuredProviders = AIProviderFactory.createProviders(from: aiProvidersEnv)
        
        guard !configuredProviders.isEmpty else {
            throw AnalyzeError.noProvidersConfigured
        }
        
        // Determine which provider to use
        let selectedProvider = try await AIProviderFactory.determineProvider(
            requestedType: provider == "auto" ? nil : provider,
            requestedModel: model,
            configuredProviders: configuredProviders
        )
        
        // Perform analysis
        let startTime = Date()
        let analysisText = try await selectedProvider.analyze(
            imageBase64: base64String,
            question: question
        )
        let duration = Date().timeIntervalSince(startTime)
        
        return AnalysisResult(
            analysisText: analysisText,
            modelUsed: "\(selectedProvider.name)/\(selectedProvider.model)",
            durationSeconds: duration,
            imagePath: self.imagePath
        )
    }
    
    private func outputResults(_ result: AnalysisResult) {
        if jsonOutput {
            let data = AnalysisResultData(
                analysis_text: result.analysisText,
                model_used: result.modelUsed,
                duration_seconds: result.durationSeconds,
                image_path: result.imagePath
            )
            outputSuccess(data: data)
        } else {
            print(result.analysisText)
            print("\n👻 Peekaboo: Analyzed image with \(result.modelUsed) in \(String(format: "%.2f", result.durationSeconds))s.")
        }
    }
    
    private func handleError(_ error: Error) {
        if jsonOutput {
            let errorCode: ErrorCode
            let errorMessage: String
            
            switch error {
            case let analyzeError as AnalyzeError:
                switch analyzeError {
                case .fileNotFound:
                    errorCode = .FILE_IO_ERROR
                case .unsupportedFormat:
                    errorCode = .INVALID_ARGUMENT
                case .noProvidersConfigured:
                    errorCode = .INVALID_ARGUMENT
                }
                errorMessage = analyzeError.errorDescription ?? "Unknown error"
            case let providerError as AIProviderError:
                errorCode = .UNKNOWN_ERROR
                errorMessage = providerError.errorDescription ?? "AI provider error"
            default:
                errorCode = .UNKNOWN_ERROR
                errorMessage = error.localizedDescription
            }
            
            outputError(message: errorMessage, code: errorCode)
        } else {
            fputs("Error: \(error.localizedDescription)\n", stderr)
        }
    }
}

// MARK: - Data Models

private struct AnalysisResult {
    let analysisText: String
    let modelUsed: String
    let durationSeconds: TimeInterval
    let imagePath: String
}

private struct AnalysisResultData: Codable {
    let analysis_text: String
    let model_used: String
    let duration_seconds: Double
    let image_path: String
}

// MARK: - Errors

enum AnalyzeError: LocalizedError {
    case fileNotFound(String)
    case unsupportedFormat(String)
    case noProvidersConfigured
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Image file not found: \(path)"
        case .unsupportedFormat(let format):
            return "Unsupported image format: .\(format). Supported formats: .png, .jpg, .jpeg, .webp"
        case .noProvidersConfigured:
            return "AI analysis not configured. Set the PEEKABOO_AI_PROVIDERS environment variable."
        }
    }
}