<div align="center">
  <img src="assets/logo.png" alt="Tachikoma Logo" width="200">
  <h1>Tachikoma</h1>
</div>

[![Swift Package Manager](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)](https://swift.org/package-manager/)
[![Swift 6](https://img.shields.io/badge/Swift-6.0+-brightgreen.svg?style=flat-square)](https://swift.org/)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%2014.0+%20|%20iOS%2017.0+%20|%20watchOS%2010.0+%20|%20tvOS%2017.0+-blue.svg?style=flat-square)](https://swift.org/)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg?style=flat-square)](LICENSE)
[![GitHub release](https://img.shields.io/github/release/steipete/Tachikoma.svg?style=flat-square)](https://github.com/steipete/Tachikoma/releases)
[![CI](https://img.shields.io/github/actions/workflow/status/steipete/Tachikoma/ci.yml?branch=main&style=flat-square&label=CI)](https://github.com/steipete/Tachikoma/actions)

A comprehensive Swift package for AI model integration, providing a unified interface for multiple AI providers including OpenAI, Anthropic, Grok (xAI), and Ollama.

Named after the spider-tank AI from Ghost in the Shell, Tachikoma provides an intelligent, adaptable interface for AI services.

## Features

- **Unified API**: Single interface for multiple AI providers
- **Swift 6 Compliant**: Built with Swift 6 strict concurrency mode for maximum safety
- **Streaming Support**: Real-time streaming responses for all supported providers
- **Tool Calling**: Complete function calling support for AI agent workflows
- **Multimodal**: Support for text, images, audio, and file inputs
- **Type Safety**: Strongly-typed message handling and error management
- **Performance**: Optimized for efficiency with intelligent caching and resource management

## Supported Providers

### OpenAI
- **Models**: GPT-4o, GPT-4.1, o3, o4 series with full parameter support
- **Features**: Chat Completions API, Responses API, streaming, tool calling, multimodal
- **API Types**: Automatic selection between Chat Completions and Responses APIs

### Anthropic (Claude)
- **Models**: Claude 4 (Opus, Sonnet), Claude 3.5/3.7 series with thinking modes
- **Features**: Native streaming, tool calling, multimodal, extended reasoning
- **Capabilities**: Long-running tasks, system prompts, safety filtering

### Grok (xAI)
- **Models**: Grok 4, Grok 3, Grok 2 series with vision capabilities
- **Features**: OpenAI-compatible API, streaming, tool calling, parameter filtering
- **Performance**: High-speed inference with competitive pricing

### Ollama
- **Models**: Llama 3.3 (recommended), Mistral, CodeLlama, and vision models
- **Features**: Local inference, tool calling (select models), streaming
- **Deployment**: Self-hosted with configurable endpoints

## Installation

### Swift Package Manager

Add Tachikoma as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/steipete/Tachikoma", from: "1.0.0")
]
```

### Requirements

- macOS 14.0+, iOS 17.0+, watchOS 10.0+, tvOS 17.0+
- Swift 6.0+
- Xcode 16.0+

## Quick Start

### Basic Usage

```swift
import Tachikoma

// Get a model instance
let tachikoma = Tachikoma.shared
let model = try await tachikoma.getModel("claude-opus-4")

// Create a simple request
let request = ModelRequest(
    messages: [
        .user(content: .text("What is the capital of France?"))
    ]
)

// Get response
let response = try await model.getResponse(request: request)
print(response.content.first?.text ?? "No response")
```

### Streaming Responses

```swift
let request = ModelRequest(
    messages: [.user(content: .text("Write a story about AI"))],
    settings: ModelSettings(temperature: 0.7)
)

for try await event in try await model.getStreamedResponse(request: request) {
    switch event {
    case .textDelta(let delta):
        print(delta.delta, terminator: "")
    case .responseCompleted:
        print("\n[Stream completed]")
    default:
        break
    }
}
```

### Tool Calling

```swift
// Define a tool
let weatherTool = ToolDefinition(
    function: FunctionDefinition(
        name: "get_weather",
        description: "Get current weather for a location",
        parameters: ToolParameters(
            type: "object",
            properties: [
                "location": ParameterSchema(
                    type: .string,
                    description: "City name"
                )
            ],
            required: ["location"]
        )
    )
)

let request = ModelRequest(
    messages: [.user(content: .text("What's the weather in Tokyo?"))],
    tools: [weatherTool],
    settings: ModelSettings(toolChoice: .auto)
)

let response = try await model.getResponse(request: request)
// Handle tool calls in response.content
```

### Multimodal Inputs

```swift
let imageData = Data(contentsOf: imageURL)
let base64Image = imageData.base64EncodedString()

let request = ModelRequest(
    messages: [
        .user(content: .multimodal([
            .text("What do you see in this image?"),
            .imageUrl(ImageUrl(
                base64: base64Image,
                detail: .high
            ))
        ]))
    ]
)

let response = try await model.getResponse(request: request)
```

## Configuration

### Environment Variables

```bash
# OpenAI
export OPENAI_API_KEY="sk-..."

# Anthropic
export ANTHROPIC_API_KEY="sk-ant-..."

# Grok (xAI)
export X_AI_API_KEY="xai-..."
# or
export XAI_API_KEY="xai-..."

# Ollama (optional, defaults to localhost:11434)
export OLLAMA_BASE_URL="http://localhost:11434"
```

### Provider Configuration

```swift
// Configure custom provider settings
let openAIConfig = ProviderConfiguration.openAI(
    apiKey: "your-api-key",
    baseURL: URL(string: "https://api.openai.com/v1"),
    organizationId: "org-id"
)

try await Tachikoma.shared.configureProvider(openAIConfig)

// Register custom model
await Tachikoma.shared.registerModel(name: "custom-gpt") {
    OpenAIModel(
        apiKey: "your-key",
        modelName: "gpt-4-custom"
    )
}
```

## Architecture

### Core Components

#### ModelInterface
The unified protocol that all AI providers implement:

```swift
protocol ModelInterface: Sendable {
    var maskedApiKey: String { get }
    func getResponse(request: ModelRequest) async throws -> ModelResponse
    func getStreamedResponse(request: ModelRequest) async throws -> AsyncThrowingStream<StreamEvent, Error>
}
```

#### Message System
Type-safe message handling with support for all content types:

```swift
public enum Message: Codable, Sendable {
    case system(id: String? = nil, content: String)
    case user(id: String? = nil, content: MessageContent)
    case assistant(id: String? = nil, content: [AssistantContent], status: MessageStatus = .completed)
    case tool(id: String? = nil, toolCallId: String, content: String)
    case reasoning(id: String? = nil, content: String)
}
```

#### Streaming System
Real-time event handling for streaming responses:

```swift
public enum StreamEvent {
    case responseStarted(StreamResponseStarted)
    case textDelta(StreamTextDelta)
    case toolCallDelta(StreamToolCallDelta)
    case toolCallCompleted(StreamToolCallCompleted)
    case responseCompleted(StreamResponseCompleted)
    case error(StreamError)
}
```

#### Tool System
Comprehensive function calling with generic context support:

```swift
public struct AITool<Context> {
    public let execute: (ToolInput, Context) async throws -> ToolOutput
    public func toToolDefinition() -> ToolDefinition
}
```

### Provider Architecture

Each provider implements the `ModelInterface` with provider-specific optimizations:

- **OpenAI**: Dual API support (Chat Completions + Responses API)
- **Anthropic**: Native SSE streaming with content blocks
- **Grok**: OpenAI-compatible with parameter filtering
- **Ollama**: Local inference with tool calling detection

### Error Handling

Comprehensive error types with recovery suggestions:

```swift
public enum TachikomaError: Error, LocalizedError {
    case modelNotFound(String)
    case authenticationFailed
    case rateLimited
    case insufficientQuota
    case contextLengthExceeded
    // ... more cases with detailed descriptions
    
    public var isRetryable: Bool { /* ... */ }
    public var recoverySuggestion: String? { /* ... */ }
}
```

## Advanced Usage

### Custom Providers

```swift
class CustomAIModel: ModelInterface {
    var maskedApiKey: String { "custom-***" }
    
    func getResponse(request: ModelRequest) async throws -> ModelResponse {
        // Custom implementation
    }
    
    func getStreamedResponse(request: ModelRequest) async throws -> AsyncThrowingStream<StreamEvent, Error> {
        // Custom streaming implementation
    }
}

// Register the custom provider
await Tachikoma.shared.registerModel(name: "custom-ai") {
    CustomAIModel()
}
```

### Batch Processing

```swift
let requests = [
    ModelRequest(messages: [.user(content: .text("Question 1"))]),
    ModelRequest(messages: [.user(content: .text("Question 2"))]),
    ModelRequest(messages: [.user(content: .text("Question 3"))])
]

let responses = try await withThrowingTaskGroup(of: ModelResponse.self) { group in
    for request in requests {
        group.addTask {
            try await model.getResponse(request: request)
        }
    }
    
    var results: [ModelResponse] = []
    for try await response in group {
        results.append(response)
    }
    return results
}
```

### Tool Context Management

```swift
struct WeatherContext {
    let apiKey: String
    let units: String
}

let weatherTool = AITool<WeatherContext> { input, context in
    let location = input.parameters["location"] as? String ?? ""
    // Use context.apiKey and context.units for API call
    return ToolOutput(content: "Weather data for \(location)")
}

// Use with context
let context = WeatherContext(apiKey: "weather-key", units: "metric")
let toolDefinition = weatherTool.toToolDefinition()
```

## Testing

Tachikoma includes comprehensive test coverage:

```bash
# Run tests
swift test

# Run with verbose output
swift test --verbose

# Run specific test suites
swift test --filter "ModelProviderTests"
```

### Mock Providers

```swift
class MockModel: ModelInterface {
    var maskedApiKey: String = "mock-***"
    var responses: [ModelResponse] = []
    
    func getResponse(request: ModelRequest) async throws -> ModelResponse {
        return responses.removeFirst()
    }
}

// Use in tests
let mockModel = MockModel()
mockModel.responses = [/* test responses */]
await Tachikoma.shared.registerModel(name: "mock") { mockModel }
```

## Performance Considerations

### Caching
- Model instances are cached by default
- Clear cache with `ModelProvider.shared.clearCache()`
- Disable caching for specific models if needed

### Memory Management
- Streaming responses use `AsyncThrowingStream` for memory efficiency
- Large responses are processed incrementally
- Tool contexts should be lightweight for optimal performance

### Concurrency
- All APIs are actor-safe and Swift 6 compliant
- Use `TaskGroup` for parallel processing
- Respect rate limits with proper error handling

## Migration Guide

### From PeekabooCore

If migrating from PeekabooCore's AI system:

1. Replace `PeekabooError` with `TachikomaError`
2. Update import statements
3. Use `Tachikoma.shared.getModel()` instead of direct model creation
4. Update streaming event handling for new event types

### Version History

- **v1.0.0**: Initial release with Swift 6 support
- Core providers: OpenAI, Anthropic, Grok, Ollama
- Complete tool calling and streaming support

## Documentation

- **[Architecture Guide](docs/ARCHITECTURE.md)**: Detailed technical architecture and design decisions
- **[Changelog](CHANGELOG.md)**: Version history and release notes
- **[API Reference](https://steipete.github.io/Tachikoma/)**: Complete API documentation

## Contributing

1. Fork the repository
2. Create a feature branch
3. Ensure Swift 6 strict mode compliance
4. Add comprehensive tests
5. Update documentation
6. Submit a pull request

## License

Tachikoma is available under the MIT License. See LICENSE for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/steipete/Tachikoma/issues)
- **Discussions**: [GitHub Discussions](https://github.com/steipete/Tachikoma/discussions)
- **Documentation**: [API Reference](https://steipete.github.io/Tachikoma/)

---

Built with ❤️ for the Swift AI community.
