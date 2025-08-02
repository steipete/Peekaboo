# Tachikoma Architecture

This document provides a detailed technical overview of the Tachikoma AI integration library architecture.

## Overview

Tachikoma is designed as a modular, type-safe Swift package that abstracts AI provider differences behind a unified interface. The architecture emphasizes Swift 6 concurrency safety, performance, and extensibility.

## Core Architecture Principles

### 1. Protocol-Oriented Design
All AI providers implement the `ModelInterface` protocol, ensuring consistent behavior across different services while allowing provider-specific optimizations.

### 2. Swift 6 Strict Concurrency
- All public APIs are actor-safe
- Sendable conformance throughout the type system
- `@MainActor` isolation where appropriate
- No data races or concurrency issues

### 3. Type Safety
- Strongly-typed message system with enum-based content types
- Compile-time verification of tool parameters
- Generic tool system with context type safety

### 4. Performance First
- Intelligent caching with configurable policies
- Streaming responses with minimal memory overhead
- Lazy provider initialization
- Efficient JSON handling without reflection

## Module Structure

```
Tachikoma/
├── Sources/Tachikoma/
│   ├── Tachikoma.swift              # Main API entry point
│   ├── Core/                        # Core abstractions
│   │   ├── ModelInterface.swift     # Provider protocol
│   │   ├── ModelProvider.swift      # Provider registry & management
│   │   ├── MessageTypes.swift       # Message type system
│   │   ├── StreamingTypes.swift     # Streaming event system
│   │   ├── ModelParameters.swift    # Request/response parameters
│   │   ├── ToolDefinitions.swift    # Tool calling system
│   │   └── TachikomaError.swift     # Error handling
│   └── Providers/                   # Provider implementations
│       ├── OpenAI/
│       │   ├── OpenAIModel.swift    # OpenAI implementation
│       │   └── OpenAITypes.swift    # OpenAI-specific types
│       ├── Anthropic/
│       │   ├── AnthropicModel.swift # Anthropic implementation
│       │   └── AnthropicTypes.swift # Anthropic-specific types
│       ├── Grok/
│       │   ├── GrokModel.swift      # Grok implementation
│       │   └── GrokTypes.swift      # Grok-specific types
│       └── Ollama/
│           ├── OllamaModel.swift    # Ollama implementation
│           └── OllamaTypes.swift    # Ollama-specific types
```

## Core Components

### ModelInterface Protocol

The central abstraction that all providers implement:

```swift
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public protocol ModelInterface: Sendable {
    /// Masked API key for debugging
    var maskedApiKey: String { get }
    
    /// Get a single response
    func getResponse(request: ModelRequest) async throws -> ModelResponse
    
    /// Get streaming response
    func getStreamedResponse(request: ModelRequest) async throws -> AsyncThrowingStream<StreamEvent, any Error>
}
```

**Key Design Decisions:**
- `Sendable` conformance ensures thread safety
- Async/await for all network operations
- Streaming uses `AsyncThrowingStream` for memory efficiency
- Availability annotations ensure compatibility

### Message Type System

Hierarchical message types that handle all AI interaction patterns:

```swift
public enum Message: Codable, Sendable {
    case system(id: String? = nil, content: String)
    case user(id: String? = nil, content: MessageContent)
    case assistant(id: String? = nil, content: [AssistantContent], status: MessageStatus = .completed)
    case tool(id: String? = nil, toolCallId: String, content: String)
    case reasoning(id: String? = nil, content: String)
}
```

**Content Type Hierarchy:**
- `MessageContent`: Text, images, multimodal, files, audio
- `AssistantContent`: Text output, refusals, tool calls
- `ImageContent`: URLs, base64 data, detail levels
- `AudioContent`: Transcripts, durations, metadata

**Benefits:**
- Type safety prevents invalid message construction
- Codable conformance for persistence
- Sendable for concurrency safety
- Extensible for new content types

### Streaming System

Real-time event processing with comprehensive event types:

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

**Stream Processing Flow:**
1. `responseStarted` - Metadata and initialization
2. `textDelta` - Incremental text content
3. `toolCallDelta` - Incremental tool call construction
4. `toolCallCompleted` - Complete tool call available
5. `responseCompleted` - Stream finished with final metadata
6. `error` - Error events for handling failures

**Implementation Details:**
- Each provider converts its streaming format to unified events
- Back-pressure handling through `AsyncThrowingStream`
- Automatic event ordering and consistency validation

### Tool Calling System

Generic, type-safe tool execution with context support:

```swift
public struct Tool<Context> {
    public let execute: (ToolInput, Context) async throws -> ToolOutput
    
    public func toToolDefinition() -> ToolDefinition {
        // Convert to provider-agnostic definition
    }
}
```

**Type Safety Features:**
- Generic context ensures compile-time type checking
- Parameter validation through JSON Schema
- Async execution for I/O operations
- Error handling with structured failures

**Tool Definition System:**
```swift
public struct ToolDefinition {
    public let function: FunctionDefinition
    public let type: ToolType = .function
}

public struct FunctionDefinition {
    public let name: String
    public let description: String?
    public let parameters: ToolParameters
}
```

### Error Handling

Comprehensive error system with recovery guidance:

```swift
public enum TachikomaError: Error, LocalizedError {
    case modelNotFound(String)
    case authenticationFailed
    case invalidConfiguration(String)
    case networkError(underlying: any Error)
    case rateLimited
    case insufficientQuota
    case contextLengthExceeded
    // ... more cases
    
    public var isRetryable: Bool { /* logic */ }
    public var recoverySuggestion: String? { /* guidance */ }
}
```

**Error Categories:**
- **Client Errors**: Invalid requests, configuration issues
- **Authentication Errors**: API key problems, quota issues
- **Network Errors**: Connectivity, timeouts, server errors
- **Provider Errors**: Model-specific limitations

## Provider Implementations

### OpenAI Provider

**Dual API Support:**
- Chat Completions API (`/v1/chat/completions`) for standard models
- Responses API (`/v1/responses`) for o3/o4 reasoning models

**Key Features:**
- Automatic API selection based on model capabilities
- Parameter filtering (o3/o4 models don't support temperature)
- Reasoning summary handling for thinking models
- Complete streaming support for both APIs

**Implementation Highlights:**
```swift
private func convertToOpenAIRequest(_ request: ModelRequest, stream: Bool) throws -> OpenAIRequest {
    // Convert unified request to OpenAI format
    // Handle parameter filtering
    // Support both API formats
}
```

### Anthropic Provider

**Native Claude Integration:**
- Direct Claude API with proper message formatting
- Content blocks for multimodal inputs
- System prompt separation
- Tool result handling as user messages

**Streaming Implementation:**
- Server-Sent Events (SSE) processing
- Delta accumulation for tool calls
- Proper handling of Claude's content block structure

**Claude 4 Features:**
- Extended thinking modes
- Long-running task support
- Advanced reasoning capabilities

### Grok Provider

**OpenAI Compatibility:**
- Uses OpenAI-compatible Chat Completions API
- Parameter filtering for Grok 3/4 models
- Standard streaming implementation

**Optimizations:**
- Efficient parameter encoding
- Proper error response handling
- Rate limiting awareness

### Ollama Provider

**Local Inference:**
- HTTP API for local models
- Custom timeout handling (5 minutes for model loading)
- Tool calling detection for compatible models

**Model Support:**
- Language models: llama3.3, mistral, etc.
- Vision models: llava, bakllava (no tool calling)
- Custom model endpoints

## Provider Registry & Management

### ModelProvider (Actor)

Central registry for all model factories and instances:

```swift
@MainActor
public final class ModelProvider {
    public static let shared = ModelProvider()
    
    private var modelFactories: [String: @Sendable () throws -> any ModelInterface] = [:]
    private var modelCache: [String: any ModelInterface] = [:]
    
    public func getModel(_ modelName: String) async throws -> any ModelInterface
    public func register(modelName: String, factory: @escaping @Sendable () throws -> any ModelInterface)
}
```

**Registration System:**
- Default model registration at startup
- Custom factory registration
- Lenient name matching (e.g., "gpt" → "gpt-4.1")
- Provider/model path resolution ("openai/gpt-4")

**Caching Strategy:**
- Model instances cached after first creation
- Cache invalidation on registration changes
- Memory-efficient with weak references where appropriate

## Concurrency & Threading

### Actor Usage

**ModelProvider as MainActor:**
- Centralizes model management
- Ensures thread-safe registration
- Coordinates provider initialization

**Sendable Conformance:**
- All message types are Sendable
- Model instances are Sendable
- Error types are Sendable
- Tool definitions are Sendable

**Async/Await Integration:**
- All network operations are async
- Streaming uses AsyncThrowingStream
- No blocking operations on main thread

### Memory Management

**Streaming Efficiency:**
- Events processed incrementally
- No accumulation of entire responses
- Automatic memory cleanup

**Cache Management:**
- Model instances cached intelligently
- Configurable cache policies
- Weak references for large objects

## Security Considerations

### API Key Handling

**Environment Variables:**
- Support for multiple key formats
- Secure key storage recommendations
- Masked keys in debug output

**Key Security:**
- Never log full API keys
- Secure transmission only
- No persistence of keys in plain text

### Input Validation

**Parameter Validation:**
- Type-safe parameter construction
- Range validation for numeric parameters
- Required field enforcement

**Content Filtering:**
- Provider-specific content policies
- Error handling for filtered content
- Transparent policy communication

## Performance Characteristics

### Network Efficiency

**Connection Management:**
- URLSession with appropriate timeouts
- HTTP/2 support where available
- Connection pooling

**Request Optimization:**
- Minimal payload size
- Efficient JSON encoding
- Compression support

### Memory Usage

**Streaming Responses:**
- Constant memory usage regardless of response size
- Incremental processing
- Automatic garbage collection

**Object Creation:**
- Minimal allocations in hot paths
- Reuse of formatter objects
- Efficient string handling

## Testing Strategy

### Unit Tests

**Provider Tests:**
- Mock network responses
- Error condition testing
- Parameter validation tests

**Integration Tests:**
- End-to-end flow testing
- Streaming behavior validation
- Tool calling integration

**Performance Tests:**
- Memory usage profiling
- Response time benchmarks
- Concurrent request handling

## Extension Points

### Custom Providers

Implement `ModelInterface` to add new providers:

```swift
class CustomProvider: ModelInterface {
    var maskedApiKey: String { "custom-***" }
    
    func getResponse(request: ModelRequest) async throws -> ModelResponse {
        // Custom implementation
    }
    
    func getStreamedResponse(request: ModelRequest) async throws -> AsyncThrowingStream<StreamEvent, Error> {
        // Custom streaming
    }
}
```

### Message Type Extensions

Add new content types by extending `MessageContent`:

```swift
extension MessageContent {
    case customType(CustomData)
}
```

### Tool System Extensions

Create specialized tool contexts:

```swift
struct DatabaseContext {
    let connection: DatabaseConnection
    let schema: Schema
}

let dbTool = Tool<DatabaseContext> { input, context in
    // Database operations with type-safe context
}
```

## Future Considerations

### Planned Features

**Enhanced Caching:**
- Persistent cache with TTL
- Smart cache invalidation
- Distributed caching support

**Advanced Streaming:**
- Bidirectional streaming
- Stream multiplexing
- Custom event types

**Provider Enhancements:**
- More granular configuration
- Provider-specific optimizations
- Enhanced error recovery

### Scalability

**High-Volume Usage:**
- Connection pooling improvements
- Request batching
- Rate limiting integration

**Enterprise Features:**
- Audit logging
- Metrics collection
- Custom authentication

---

This architecture provides a solid foundation for AI integration while maintaining flexibility for future enhancements and provider additions.